import '../models/ledger_entry.dart';
import '../models/profit_summary.dart';
import '../models/saved_bill.dart';
import 'storage_service.dart';

class ProfitService {
  final StorageService _storage;

  ProfitService([StorageService? storage])
      : _storage = storage ?? StorageService();

  bool _isInMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  Future<ProfitSummary> calculateSummary({DateTime? month}) async {
    final bills = await _storage.getSavedBills();
    final ledgerEntries = await _storage.getLedgerEntries();
    final stockEntries = await _storage.getStockEntries();

    final billsInPeriod = <SavedBill>[];
    for (final bill in bills) {
      if (month != null && !_isInMonth(bill.date, month)) continue;
      billsInPeriod.add(bill);
    }

    final billIds = billsInPeriod.map((bill) => bill.ledgerEntryId).toSet();

    double totalSales = 0;
    double totalWeightSold = 0;
    for (final bill in billsInPeriod) {
      totalSales += bill.totalAmount;
      totalWeightSold += bill.totalWeight;
    }

    final cogs = _storage.calculateCogsForBillOuts(stockEntries, billIds);

    double totalPayments = 0;
    int paymentCount = 0;
    for (final entry in ledgerEntries) {
      if (!entry.isPayment) continue;
      if (month != null && !_isInMonth(entry.date, month)) continue;
      totalPayments += entry.amount;
      paymentCount++;
    }

    return ProfitSummary(
      totalSales: totalSales,
      totalPayments: totalPayments,
      costOfGoodsSold: cogs,
      grossProfit: totalSales - cogs,
      billCount: billsInPeriod.length,
      paymentCount: paymentCount,
      totalWeightSold: totalWeightSold,
    );
  }

  Future<List<DateTime>> availableMonths() async {
    final months = <String, DateTime>{};
    final bills = await _storage.getSavedBills();
    final entries = await _storage.getLedgerEntries();

    for (final bill in bills) {
      final key = '${bill.date.year}-${bill.date.month}';
      months[key] = DateTime(bill.date.year, bill.date.month);
    }
    for (final entry in entries) {
      final key = '${entry.date.year}-${entry.date.month}';
      months[key] = DateTime(entry.date.year, entry.date.month);
    }

    final list = months.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }
}
