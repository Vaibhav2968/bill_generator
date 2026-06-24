import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../models/saved_bill.dart';
import '../services/storage_service.dart';
import '../utils/bill_number_utils.dart';
import '../utils/whatsapp_utils.dart';
import '../widgets/bill_number_dialog.dart';

class BillPage extends StatefulWidget {
  final Customer customer;
  final String? ledgerEntryId;
  final DateTime? billDate;
  final String billDetails;
  final String total;
  final String price;
  final String weight;
  final String amount;
  final String gauge;
  final String billDetailsFormatted;
  final double totalAmount;
  final double totalWeight;
  final String billNumber;
  final bool showReturnHome;

  const BillPage({
    super.key,
    required this.customer,
    required this.billDetails,
    required this.total,
    required this.price,
    required this.weight,
    required this.amount,
    required this.gauge,
    required this.billDetailsFormatted,
    required this.totalAmount,
    required this.totalWeight,
    this.billNumber = '',
    this.ledgerEntryId,
    this.billDate,
    this.showReturnHome = true,
  });

  factory BillPage.fromSaved(SavedBill saved, Customer customer) {
    return BillPage(
      customer: customer,
      ledgerEntryId: saved.ledgerEntryId,
      billDate: saved.date,
      billNumber: saved.billNumber,
      billDetails: saved.billDetails,
      total: saved.total,
      price: saved.price,
      weight: saved.weight,
      amount: saved.amount,
      gauge: saved.gauge,
      billDetailsFormatted: saved.billDetailsFormatted,
      totalAmount: saved.totalAmount,
      totalWeight: saved.totalWeight,
      showReturnHome: false,
    );
  }

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  final StorageService _storage = StorageService();

  late String billDetails;
  late String billDetailsFormatted;
  late String total;
  late String price;
  late String weight;
  late String amount;
  late String gauge;
  late double totalAmount;
  late double totalWeight;
  late String billNumber;

  @override
  void initState() {
    super.initState();
    billNumber = widget.billNumber;
    _applyBillData(
      billDetails: widget.billDetails,
      billDetailsFormatted: widget.billDetailsFormatted,
      total: widget.total,
      price: widget.price,
      weight: widget.weight,
      amount: widget.amount,
      gauge: widget.gauge,
      totalAmount: widget.totalAmount,
      totalWeight: widget.totalWeight,
    );
  }

  void _applyBillData({
    required String billDetails,
    required String billDetailsFormatted,
    required String total,
    required String price,
    required String weight,
    required String amount,
    required String gauge,
    required double totalAmount,
    required double totalWeight,
  }) {
    this.billDetails = billDetails;
    this.billDetailsFormatted = billDetailsFormatted;
    this.total = total;
    this.price = price;
    this.weight = weight;
    this.amount = amount;
    this.gauge = gauge;
    this.totalAmount = totalAmount;
    this.totalWeight = totalWeight;
  }

  String get _dateText =>
      DateFormat.yMMMd().format(widget.billDate ?? DateTime.now());

  Future<void> _persistBill() async {
    if (widget.ledgerEntryId == null) return;

    final existingBill =
        await _storage.getSavedBill(widget.ledgerEntryId!);

    final saved = SavedBill(
      ledgerEntryId: widget.ledgerEntryId!,
      customerId: widget.customer.id,
      date: widget.billDate ?? DateTime.now(),
      billNumber: billNumber,
      billDetails: billDetails,
      billDetailsFormatted: billDetailsFormatted,
      total: total,
      price: price,
      weight: weight,
      amount: amount,
      gauge: gauge,
      totalAmount: totalAmount,
      totalWeight: totalWeight,
      lineItems: existingBill?.lineItems ?? const [],
    );
    await _storage.saveSavedBill(saved);
    if (billNumber.isNotEmpty) {
      await _storage.reserveBillNumber(billNumber);
    }

    final entries = await _storage.getLedgerEntries();
    final index = entries.indexWhere((e) => e.id == widget.ledgerEntryId);
    if (index >= 0) {
      final existing = entries[index];
      await _storage.updateLedgerEntry(
        LedgerEntry(
          id: existing.id,
          customerId: existing.customerId,
          date: existing.date,
          type: existing.type,
          amount: totalAmount,
          note: billNumber.isNotEmpty ? billNumber : existing.note,
        ),
      );
    }
  }

  Future<void> _changeBillNumber() async {
    final billDate = widget.billDate ?? DateTime.now();
    final suggested = billNumber.isNotEmpty
        ? billNumber
        : await _storage.peekNextBillNumber(billDate);
    if (!mounted) return;

    final updated = await showBillNumberDialog(
      context,
      suggested: suggested,
      date: billDate,
    );
    if (updated == null || updated.isEmpty) return;

    setState(() => billNumber = updated);
    await _persistBill();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill number updated to $updated')),
      );
    }
  }

  Future<void> _editBill() async {
    final billNumberController = TextEditingController(text: billNumber);
    final gaugeController = TextEditingController(text: gauge.trim());
    final priceController = TextEditingController(text: price.trim());
    final weightController = TextEditingController(text: weight.trim());
    final amountController = TextEditingController(text: amount.trim());
    final totalWeightController =
        TextEditingController(text: totalWeight.toString());
    final totalAmountController =
        TextEditingController(text: totalAmount.round().toString());
    final controllers = [
      billNumberController,
      gaugeController,
      priceController,
      weightController,
      amountController,
      totalWeightController,
      totalAmountController,
    ];

    final draft = await showDialog<_EditBillDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bill'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: billNumberController,
                decoration: const InputDecoration(
                  labelText: 'Bill number',
                  hintText: 'e.g. 1-2627',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gaugeController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Gauge (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Price (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Weight (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Amount (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalWeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total weight (kg)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total amount (Rs.)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _EditBillDraft(
                  billNumber: billNumberController.text,
                  gauge: gaugeController.text,
                  price: priceController.text,
                  weight: weightController.text,
                  amount: amountController.text,
                  totalWeight: totalWeightController.text,
                  totalAmount: totalAmountController.text,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    if (draft == null) return;

    final newBillNumber = BillNumberUtils.normalize(
      draft.billNumber,
      widget.billDate ?? DateTime.now(),
    );
    final newGauge = '${draft.gauge.trim()}\n';
    final newPrice = '${draft.price.trim()}\n';
    final newWeight = '${draft.weight.trim()}\n';
    final newAmount = '${draft.amount.trim()}\n';
    final newTotalWeight =
        double.tryParse(draft.totalWeight.trim()) ?? totalWeight;
    final newTotalAmount =
        double.tryParse(draft.totalAmount.trim()) ?? totalAmount;

    final gauges = draft.gauge
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final prices = draft.price
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final weights = draft.weight
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final amounts = draft.amount
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final formatted = StringBuffer();
    final details = StringBuffer();
    final lineCount = [
      gauges.length,
      prices.length,
      weights.length,
      amounts.length,
    ].reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < lineCount; i++) {
      final g = i < gauges.length ? gauges[i] : '';
      final p = i < prices.length ? prices[i] : '';
      final w = i < weights.length ? weights[i] : '';
      final a = i < amounts.length ? amounts[i] : '';
      final gaugeLabel = g.replaceAll(' swg', '');
      details.writeln(
        'Gauge:$gaugeLabel , Price:$p, Weight:$w,  Amount:$a',
      );
      details.writeln();
      formatted.writeln('Gauge:$gaugeLabel');
      formatted.writeln('Price:$p');
      formatted.writeln('Weight:$w');
      formatted.writeln('Amount:$a');
      formatted.writeln();
    }

    formatted.writeln('TOTAL WEIGHT: $newTotalWeight kg');
    formatted.writeln('TOTAL:    ${newTotalAmount.round()}');
    details.writeln('TOTAL WEIGHT: $newTotalWeight kg');
    details.writeln('TOTAL:    ${newTotalAmount.round()}');

    setState(() {
      billNumber = newBillNumber;
      _applyBillData(
        billDetails: details.toString().trim(),
        billDetailsFormatted: formatted.toString().trim(),
        total:
            '\nTOTAL WEIGHT: $newTotalWeight kg\nTOTAL: Rs. ${newTotalAmount.round()}',
        price: newPrice,
        weight: newWeight,
        amount: newAmount,
        gauge: newGauge,
        totalAmount: newTotalAmount,
        totalWeight: newTotalWeight,
      );
    });

    await _persistBill();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill updated')),
      );
    }
  }

  Future<void> _deleteBill() async {
    if (widget.ledgerEntryId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bill?'),
        content: const Text(
          'This will remove the bill from the ledger, restore stock, and update the due balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _storage.deleteLedgerEntry(widget.ledgerEntryId!);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> shareBillOnWhatsApp() async {
    final message = billNumber.isNotEmpty
        ? 'Bill No: $billNumber\n'
            'Date: $_dateText\n\n'
            'Customer Name: ${widget.customer.name}\n\n'
            '$billDetailsFormatted\n\n'
            'Thank you'
        : 'Date: $_dateText\n\n'
            'Customer Name: ${widget.customer.name}\n\n'
            '$billDetailsFormatted\n\n'
            'Thank you';

    final opened = await WhatsAppUtils.shareText(
      phone: widget.customer.whatsappNumber,
      message: message,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bill'),
        actions: [
          if (widget.ledgerEntryId != null)
            IconButton(
              onPressed: _changeBillNumber,
              icon: const Icon(Icons.tag),
              tooltip: 'Change bill number',
            ),
          if (widget.ledgerEntryId != null) ...[
            IconButton(
              onPressed: _editBill,
              icon: const Icon(Icons.edit),
              tooltip: 'Edit bill',
            ),
            IconButton(
              onPressed: _deleteBill,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete bill',
            ),
          ],
          IconButton(
            onPressed: shareBillOnWhatsApp,
            icon: const Icon(Icons.message),
            tooltip: 'Share on WhatsApp',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Date:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _dateText,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (billNumber.isNotEmpty) ...[
                      Text(
                        'Bill No:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        billNumber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[700],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Customer Name:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.customer.name,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(thickness: 2, color: Colors.blueGrey[400]),
                    const SizedBox(height: 20),
                    const Text(
                      'Bill Details:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _billColumn('Gauge', gauge),
                          const VerticalDivider(),
                          _billColumn('Price', price),
                          const VerticalDivider(),
                          _billColumn('Weight', weight),
                          const VerticalDivider(),
                          _billColumn('Amount', amount),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      total,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: shareBillOnWhatsApp,
                    icon: const Icon(Icons.message),
                    label: const Text('WhatsApp'),
                  ),
                  if (widget.ledgerEntryId != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _persistBill();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bill saved')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                ],
              ),
            ),
            if (widget.showReturnHome)
              Padding(
                padding: const EdgeInsets.all(50),
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  ),
                  child: const Text('Return to Home'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _billColumn(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 15, color: Colors.blueGrey[600]),
          ),
        ],
      ),
    );
  }
}

class _EditBillDraft {
  final String billNumber;
  final String gauge;
  final String price;
  final String weight;
  final String amount;
  final String totalWeight;
  final String totalAmount;

  const _EditBillDraft({
    required this.billNumber,
    required this.gauge,
    required this.price,
    required this.weight,
    required this.amount,
    required this.totalWeight,
    required this.totalAmount,
  });
}
