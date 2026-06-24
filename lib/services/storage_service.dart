import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill_stock_line.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../models/purchase.dart';
import '../models/saved_bill.dart';
import '../models/stock_entry.dart';
import '../utils/bill_number_utils.dart';
import '../utils/gauge_utils.dart';
import '../utils/stock_utils.dart';

class StorageService {
  static const _customersKey = 'customers_v1';
  static const _ledgerKey = 'ledger_v1';
  static const _billHistoryKey = 'billHistory';
  static const _savedBillsKey = 'saved_bills_v1';
  static const _stockEntriesKey = 'stock_entries_v1';
  static const _stockBasePriceKey = 'stock_base_price_v1';
  static const _purchasesKey = 'purchases_v1';
  static const _purchasePaymentsKey = 'purchase_payments_v1';

  Future<List<Customer>> getCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCustomers(List<Customer> customers) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(customers.map((c) => c.toJson()).toList());
    await prefs.setString(_customersKey, encoded);
  }

  Future<Customer> upsertCustomer(Customer customer) async {
    final customers = await getCustomers();
    final index = customers.indexWhere((c) => c.id == customer.id);
    if (index >= 0) {
      customers[index] = customer;
    } else {
      customers.add(customer);
    }
    customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await saveCustomers(customers);
    return customer;
  }

  Future<void> deleteCustomer(String id) async {
    final customers = await getCustomers();
    customers.removeWhere((c) => c.id == id);
    await saveCustomers(customers);
  }

  Future<List<LedgerEntry>> getLedgerEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ledgerKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LedgerEntry>> getLedgerForCustomer(String customerId) async {
    final entries = await getLedgerEntries();
    return entries.where((e) => e.customerId == customerId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addLedgerEntry(LedgerEntry entry) async {
    final entries = await getLedgerEntries();
    entries.add(entry);
    await _saveLedgerEntries(entries);
  }

  Future<void> updateLedgerEntry(LedgerEntry entry) async {
    final entries = await getLedgerEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
      await _saveLedgerEntries(entries);
    }
  }

  Future<void> deletePaymentEntry(String id) async {
    final entries = await getLedgerEntries();
    entries.removeWhere((e) => e.id == id);
    await _saveLedgerEntries(entries);
  }

  Future<void> deleteLedgerEntry(String id) async {
    final entries = await getLedgerEntries();
    entries.removeWhere((e) => e.id == id);
    await _saveLedgerEntries(entries);
    await restoreStockForBill(id);
    await deleteSavedBill(id);
  }

  Future<void> _saveLedgerEntries(List<LedgerEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ledgerKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<SavedBill>> getSavedBills() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedBillsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedBill.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SavedBill?> getSavedBill(String ledgerEntryId) async {
    final bills = await getSavedBills();
    for (final bill in bills) {
      if (bill.ledgerEntryId == ledgerEntryId) {
        return bill;
      }
    }
    return null;
  }

  Future<void> saveSavedBill(SavedBill bill) async {
    final bills = await getSavedBills();
    final index =
        bills.indexWhere((b) => b.ledgerEntryId == bill.ledgerEntryId);
    if (index >= 0) {
      bills[index] = bill;
    } else {
      bills.add(bill);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedBillsKey,
      jsonEncode(bills.map((b) => b.toJson()).toList()),
    );
  }

  Future<void> deleteSavedBill(String ledgerEntryId) async {
    final bills = await getSavedBills();
    bills.removeWhere((b) => b.ledgerEntryId == ledgerEntryId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedBillsKey,
      jsonEncode(bills.map((b) => b.toJson()).toList()),
    );
  }

  Future<double> getCustomerBalance(String customerId) async {
    final entries = await getLedgerForCustomer(customerId);
    double balance = 0;
    for (final entry in entries) {
      if (entry.isBill) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  Future<({double totalDue, int customersWithDue, Map<String, double> balances})>
      getDueSummary() async {
    final customers = await getCustomers();
    final entries = await getLedgerEntries();
    final balances = <String, double>{};

    for (final entry in entries) {
      final delta = entry.isBill ? entry.amount : -entry.amount;
      balances[entry.customerId] = (balances[entry.customerId] ?? 0) + delta;
    }

    double totalDue = 0;
    int customersWithDue = 0;
    for (final customer in customers) {
      final balance = balances[customer.id] ?? 0;
      balances[customer.id] = balance;
      if (balance > 0) {
        totalDue += balance;
        customersWithDue++;
      }
    }

    return (
      totalDue: totalDue,
      customersWithDue: customersWithDue,
      balances: balances,
    );
  }

  Future<void> addBillToHistory(String billString) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_billHistoryKey) ?? [];
    history.add(billString);
    await prefs.setStringList(_billHistoryKey, history);
  }

  Future<List<String>> getBillHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_billHistoryKey) ?? [];
  }

  Future<void> saveBillHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_billHistoryKey, history);
  }

  String _billCounterKey(String fySuffix) => 'bill_seq_$fySuffix';

  Future<String> peekNextBillNumber([DateTime? date]) async {
    final billDate = date ?? DateTime.now();
    final fy = BillNumberUtils.financialYearSuffix(billDate);
    final prefs = await SharedPreferences.getInstance();
    final next = prefs.getInt(_billCounterKey(fy)) ?? 1;
    return '$next-$fy';
  }

  Future<void> reserveBillNumber(String billNumber) async {
    final parsed = BillNumberUtils.parse(billNumber);
    if (parsed == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _billCounterKey(parsed.fySuffix);
    final current = prefs.getInt(key) ?? 1;
    final nextSequence = parsed.sequence + 1;
    if (nextSequence > current) {
      await prefs.setInt(key, nextSequence);
    }
  }

  Future<void> setNextBillSequence(String fySuffix, int nextSequence) async {
    if (nextSequence < 1) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_billCounterKey(fySuffix), nextSequence);
  }

  Future<double> getStockBasePrice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_stockBasePriceKey) ?? 0;
  }

  Future<void> setStockBasePrice(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_stockBasePriceKey, price);
  }

  Future<List<StockEntry>> getStockEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stockEntriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => StockEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveStockEntries(List<StockEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stockEntriesKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addStockEntry(StockEntry entry) async {
    final entries = await getStockEntries();
    entries.add(entry);
    await _saveStockEntries(entries);
  }

  Future<void> updateStockEntry(StockEntry entry) async {
    final entries = await getStockEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
      await _saveStockEntries(entries);
    }
  }

  Future<void> deleteStockEntry(String id) async {
    final entries = await getStockEntries();
    entries.removeWhere((e) => e.id == id);
    await _saveStockEntries(entries);
  }

  List<StockSummaryItem> buildStockSummary(List<StockEntry> entries) {
    final totals = <String, double>{};
    final packingByKey = <String, bool>{};
    final gaugeByKey = <String, double>{};

    for (final entry in entries) {
      final gauge = GaugeUtils.normalizeGauge(entry.gauge) ?? entry.gauge;
      final key = StockUtils.itemKey(gauge, entry.packing2_5kg);
      packingByKey[key] = entry.packing2_5kg;
      gaugeByKey[key] = gauge;
      final delta = entry.isIncoming ? entry.weight : -entry.weight;
      totals[key] = (totals[key] ?? 0) + delta;
    }

    final summary = <StockSummaryItem>[];
    for (final entry in totals.entries) {
      final weight = entry.value;
      if (weight <= 0.001) continue;
      summary.add(
        StockSummaryItem(
          gauge: gaugeByKey[entry.key]!,
          packing2_5kg: packingByKey[entry.key]!,
          weight: weight,
        ),
      );
    }

    summary.sort((a, b) {
      final gaugeCompare = a.gauge.compareTo(b.gauge);
      if (gaugeCompare != 0) return gaugeCompare;
      return a.packing2_5kg == b.packing2_5kg
          ? 0
          : a.packing2_5kg
              ? 1
              : -1;
    });
    return summary;
  }

  double totalStockWeight(List<StockSummaryItem> summary) =>
      summary.fold<double>(0, (sum, item) => sum + item.weight);

  double calculateStockValueFromEntries(List<StockEntry> entries) {
    final summary = buildStockSummary(entries);
    var total = 0.0;
    for (final item in summary) {
      final layers = _buildFifoLayers(entries, item.gauge, item.packing2_5kg);
      for (final layer in layers) {
        total +=
            layer.remaining *
            GaugeUtils.unitPrice(
              layer.basePrice,
              item.gauge,
              packing2_5kg: item.packing2_5kg,
            );
      }
    }
    return total;
  }

  Future<List<Purchase>> getPurchases() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_purchasesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _savePurchases(List<Purchase> purchases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _purchasesKey,
      jsonEncode(purchases.map((p) => p.toJson()).toList()),
    );
  }

  Future<List<PurchasePayment>> getPurchasePayments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_purchasePaymentsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PurchasePayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _savePurchasePayments(List<PurchasePayment> payments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _purchasePaymentsKey,
      jsonEncode(payments.map((p) => p.toJson()).toList()),
    );
  }

  Future<double> getPurchasePaidAmount(String purchaseId) async {
    final payments = await getPurchasePayments();
    return payments
        .where((payment) => payment.purchaseId == purchaseId)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  Future<double> getPurchaseDue(String purchaseId) async {
    final purchases = await getPurchases();
    final purchase = purchases.firstWhere((p) => p.id == purchaseId);
    final paid = await getPurchasePaidAmount(purchaseId);
    return purchase.totalAmount - paid;
  }

  Future<double> getTotalPurchaseDue() async {
    final purchases = await getPurchases();
    var total = 0.0;
    for (final purchase in purchases) {
      final due = await getPurchaseDue(purchase.id);
      if (due > 0) total += due;
    }
    return total;
  }

  Future<Purchase> savePurchase(Purchase purchase) async {
    final purchases = await getPurchases();
    purchases.add(purchase);
    await _savePurchases(purchases);
    await _addPurchaseStockEntries(purchase);
    await setStockBasePrice(purchase.basePrice);
    return purchase;
  }

  Future<String?> validatePurchaseCanModify(String purchaseId) async {
    final entries = await getStockEntries();
    final purchaseEntries = entries
        .where(
          (entry) =>
              entry.linkedPurchaseId == purchaseId && entry.isIncoming,
        )
        .toList();

    for (final inEntry in purchaseEntries) {
      final batches = getRemainingStockBatches(
        entries,
        inEntry.gauge,
        inEntry.packing2_5kg,
      );
      final batch = batches
          .where((layer) => layer.sourceEntryId == inEntry.id)
          .firstOrNull;
      final remaining = batch?.remainingWeight ?? 0;
      if (remaining < inEntry.weight - 0.001) {
        final sold = inEntry.weight - remaining;
        return 'Cannot change this purchase — '
            '${sold.toStringAsFixed(2)} kg from '
            '${StockUtils.itemLabel(inEntry.gauge, inEntry.packing2_5kg)} '
            'has already been sold.';
      }
    }
    return null;
  }

  Future<void> _addPurchaseStockEntries(Purchase purchase) async {
    final stockEntries = await getStockEntries();
    for (var i = 0; i < purchase.lines.length; i++) {
      final line = purchase.lines[i];
      final gauge = GaugeUtils.normalizeGauge(line.gauge) ?? line.gauge;
      stockEntries.add(
        StockEntry(
          id: '${purchase.id}_$i',
          date: purchase.date,
          gauge: gauge,
          weight: line.weight,
          packing2_5kg: line.packing2_5kg,
          basePrice: purchase.basePrice,
          type: 'in',
          source: 'purchase',
          linkedPurchaseId: purchase.id,
          note: 'Base Rs. ${purchase.basePrice.round()}',
        ),
      );
    }
    await _saveStockEntries(stockEntries);
  }

  Future<void> _removePurchaseStockEntries(String purchaseId) async {
    final stockEntries = await getStockEntries();
    stockEntries.removeWhere(
      (entry) =>
          entry.linkedPurchaseId == purchaseId && entry.isIncoming,
    );
    await _saveStockEntries(stockEntries);
  }

  Future<void> deletePurchase(String purchaseId) async {
    final error = await validatePurchaseCanModify(purchaseId);
    if (error != null) {
      throw StateError(error);
    }

    final purchases = await getPurchases();
    purchases.removeWhere((purchase) => purchase.id == purchaseId);
    await _savePurchases(purchases);

    final payments = await getPurchasePayments();
    payments.removeWhere((payment) => payment.purchaseId == purchaseId);
    await _savePurchasePayments(payments);

    await _removePurchaseStockEntries(purchaseId);
  }

  Future<Purchase> updatePurchase(Purchase purchase) async {
    final error = await validatePurchaseCanModify(purchase.id);
    if (error != null) {
      throw StateError(error);
    }

    final purchases = await getPurchases();
    final index = purchases.indexWhere((item) => item.id == purchase.id);
    if (index < 0) {
      throw StateError('Purchase not found');
    }
    purchases[index] = purchase;
    await _savePurchases(purchases);

    await _removePurchaseStockEntries(purchase.id);
    await _addPurchaseStockEntries(purchase);
    await setStockBasePrice(purchase.basePrice);
    return purchase;
  }

  Future<Purchase?> getPurchaseById(String id) async {
    final purchases = await getPurchases();
    return purchases.where((purchase) => purchase.id == id).firstOrNull;
  }

  Future<void> addPurchasePayment(PurchasePayment payment) async {
    final payments = await getPurchasePayments();
    payments.add(payment);
    await _savePurchasePayments(payments);
  }

  Future<void> updatePurchasePayment(PurchasePayment payment) async {
    final payments = await getPurchasePayments();
    final index = payments.indexWhere((item) => item.id == payment.id);
    if (index >= 0) {
      payments[index] = payment;
      await _savePurchasePayments(payments);
    }
  }

  Future<void> deletePurchasePayment(String id) async {
    final payments = await getPurchasePayments();
    payments.removeWhere((payment) => payment.id == id);
    await _savePurchasePayments(payments);
  }

  double totalStockValue(
    List<StockSummaryItem> summary,
    double basePrice,
  ) =>
      summary.fold<double>(
        0,
        (sum, item) => sum + item.stockValue(basePrice),
      );

  double _availableWeight(
    List<StockSummaryItem> summary,
    double gauge,
    bool packing2_5kg,
  ) {
    final normalized = GaugeUtils.normalizeGauge(gauge) ?? gauge;
    return summary
        .where(
          (item) =>
              item.gauge == normalized && item.packing2_5kg == packing2_5kg,
        )
        .fold<double>(0, (sum, item) => sum + item.weight);
  }

  Future<List<String>> checkStockShortages(List<BillStockLine> lines) async {
    final entries = await getStockEntries();
    final summary = buildStockSummary(entries);
    final shortages = <String>[];

    for (final line in lines) {
      final gauge = GaugeUtils.normalizeGauge(line.gauge) ?? line.gauge;
      if (line.stockSourceEntryId != null) {
        final batches = getRemainingStockBatches(
          entries,
          gauge,
          line.packing2_5kg,
        );
        final batch = batches
            .where((b) => b.sourceEntryId == line.stockSourceEntryId)
            .firstOrNull;
        final available = batch?.remainingWeight ?? 0;
        if (line.weight > available + 0.001) {
          shortages.add(
            '${StockUtils.itemLabel(gauge, line.packing2_5kg)} '
            '(selected lot): need ${line.weight} kg, '
            'have ${available.toStringAsFixed(3)} kg',
          );
        }
        continue;
      }

      final available =
          _availableWeight(summary, gauge, line.packing2_5kg);
      if (line.weight > available + 0.001) {
        shortages.add(
          '${StockUtils.itemLabel(gauge, line.packing2_5kg)}: '
          'need ${line.weight} kg, have ${available.toStringAsFixed(3)} kg',
        );
      }
    }

    return shortages;
  }

  double _stockEntryCost(StockEntry entry) =>
      entry.weight *
      GaugeUtils.unitPrice(
        entry.basePrice,
        entry.gauge,
        packing2_5kg: entry.packing2_5kg,
      );

  double calculateCogsForBillOuts(
    List<StockEntry> stockEntries,
    Set<String> billIds,
  ) {
    var cogs = 0.0;
    for (final entry in stockEntries) {
      if (entry.isIncoming) continue;
      if (entry.linkedBillId == null || !billIds.contains(entry.linkedBillId)) {
        continue;
      }
      cogs += _stockEntryCost(entry);
    }
    return cogs;
  }

  List<_StockLayer> _buildFifoLayers(
    List<StockEntry> entries,
    double gauge,
    bool packing2_5kg,
  ) {
    final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
    final layers = <_StockLayer>[];

    for (final entry in sorted) {
      final entryGauge = GaugeUtils.normalizeGauge(entry.gauge) ?? entry.gauge;
      if (entryGauge != gauge || entry.packing2_5kg != packing2_5kg) continue;

      if (entry.isIncoming) {
        layers.add(
          _StockLayer(
            sourceEntryId: entry.id,
            remaining: entry.weight,
            originalWeight: entry.weight,
            basePrice: entry.basePrice,
            date: entry.date,
          ),
        );
        continue;
      }

      var toRemove = entry.weight;
      for (final layer in layers) {
        if (toRemove <= 0.001) break;
        if (layer.remaining <= 0.001) continue;
        final take = toRemove < layer.remaining ? toRemove : layer.remaining;
        layer.remaining -= take;
        toRemove -= take;
      }
    }

    return layers.where((layer) => layer.remaining > 0.001).toList();
  }

  List<StockBatch> getRemainingStockBatches(
    List<StockEntry> entries,
    double gauge,
    bool packing2_5kg,
  ) {
    final normalized = GaugeUtils.normalizeGauge(gauge) ?? gauge;
    return _buildFifoLayers(entries, normalized, packing2_5kg)
        .map(
          (layer) => StockBatch(
            sourceEntryId: layer.sourceEntryId,
            remainingWeight: layer.remaining,
            addedWeight: layer.originalWeight,
            basePrice: layer.basePrice,
            date: layer.date,
          ),
        )
        .toList();
  }

  List<StockBaseBreakdown> getAvailableStockBreakdown(
    List<StockEntry> entries,
    double gauge,
    bool packing2_5kg,
    double reservedWeight,
  ) {
    final batches = getRemainingStockBatches(entries, gauge, packing2_5kg);
    var toReserve = reservedWeight;
    final byBase = <double, double>{};

    for (final batch in batches) {
      var remaining = batch.remainingWeight;
      if (toReserve > 0.001) {
        final take =
            toReserve < remaining ? toReserve : remaining;
        remaining -= take;
        toReserve -= take;
      }
      if (remaining > 0.001) {
        byBase[batch.basePrice] = (byBase[batch.basePrice] ?? 0) + remaining;
      }
    }

    final breakdown = byBase.entries
        .map(
          (entry) => StockBaseBreakdown(
            basePrice: entry.key,
            weight: entry.value,
          ),
        )
        .toList();
    breakdown.sort((a, b) => a.basePrice.compareTo(b.basePrice));
    return breakdown;
  }

  double _averagePurchaseBase(
    List<StockEntry> entries,
    double gauge,
    bool packing2_5kg,
  ) {
    var totalWeight = 0.0;
    var totalValue = 0.0;
    for (final entry in entries) {
      if (!entry.isIncoming) continue;
      final entryGauge = GaugeUtils.normalizeGauge(entry.gauge) ?? entry.gauge;
      if (entryGauge != gauge || entry.packing2_5kg != packing2_5kg) continue;
      totalWeight += entry.weight;
      totalValue += entry.weight * entry.basePrice;
    }
    if (totalWeight <= 0) {
      return 0;
    }
    return totalValue / totalWeight;
  }

  double averagePurchaseBaseForSku(
    List<StockEntry> entries,
    double gauge,
    bool packing2_5kg,
  ) =>
      _averagePurchaseBase(entries, gauge, packing2_5kg);

  Future<void> deductStockForBill({
    required String linkedBillId,
    required String billNumber,
    required List<BillStockLine> lines,
  }) async {
    final entries = await getStockEntries();
    final now = DateTime.now();
    var outIndex = 0;

    for (final line in lines) {
      final gauge = GaugeUtils.normalizeGauge(line.gauge) ?? line.gauge;
      var remaining = line.weight;
      final layers = _buildFifoLayers(entries, gauge, line.packing2_5kg);

      if (line.stockSourceEntryId != null) {
        final layerIndex = layers.indexWhere(
          (layer) => layer.sourceEntryId == line.stockSourceEntryId,
        );
        if (layerIndex >= 0) {
          final layer = layers[layerIndex];
          if (layer.remaining > 0.001) {
            final take =
                remaining < layer.remaining ? remaining : layer.remaining;
            entries.add(
              StockEntry(
                id: '${linkedBillId}_${outIndex++}',
                date: now,
                gauge: gauge,
                weight: take,
                packing2_5kg: line.packing2_5kg,
                basePrice: layer.basePrice,
                type: 'out',
                source: 'bill',
                note: 'Bill $billNumber',
                linkedBillId: linkedBillId,
              ),
            );
            layer.remaining -= take;
            remaining -= take;
          }
        }
      }

      for (final layer in layers) {
        if (remaining <= 0.001) break;
        if (layer.remaining <= 0.001) continue;

        final take =
            remaining < layer.remaining ? remaining : layer.remaining;
        entries.add(
          StockEntry(
            id: '${linkedBillId}_${outIndex++}',
            date: now,
            gauge: gauge,
            weight: take,
            packing2_5kg: line.packing2_5kg,
            basePrice: layer.basePrice,
            type: 'out',
            source: 'bill',
            note: 'Bill $billNumber',
            linkedBillId: linkedBillId,
          ),
        );
        layer.remaining -= take;
        remaining -= take;
      }

      if (remaining > 0.001) {
        final fallbackBase = _averagePurchaseBase(
          entries,
          gauge,
          line.packing2_5kg,
        );
        entries.add(
          StockEntry(
            id: '${linkedBillId}_${outIndex++}',
            date: now,
            gauge: gauge,
            weight: remaining,
            packing2_5kg: line.packing2_5kg,
            basePrice: fallbackBase,
            type: 'out',
            source: 'bill',
            note: 'Bill $billNumber',
            linkedBillId: linkedBillId,
          ),
        );
      }
    }

    await _saveStockEntries(entries);
  }

  Future<void> restoreStockForBill(String linkedBillId) async {
    final entries = await getStockEntries();
    final updated =
        entries.where((entry) => entry.linkedBillId != linkedBillId).toList();
    if (updated.length != entries.length) {
      await _saveStockEntries(updated);
    }
  }
}

class _StockLayer {
  final String sourceEntryId;
  double remaining;
  final double originalWeight;
  final double basePrice;
  final DateTime date;

  _StockLayer({
    required this.sourceEntryId,
    required this.remaining,
    required this.originalWeight,
    required this.basePrice,
    required this.date,
  });
}
