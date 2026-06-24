import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/purchase.dart';
import '../pages/new_purchase_page.dart';
import '../services/storage_service.dart';
import '../utils/stock_utils.dart';

class _PaymentFormResult {
  final double amount;
  final String note;

  const _PaymentFormResult({
    required this.amount,
    required this.note,
  });
}

class _PurchasePaymentDialog extends StatefulWidget {
  final String title;
  final double? dueHint;
  final double? maxAmount;
  final double? initialAmount;
  final String initialNote;

  const _PurchasePaymentDialog({
    required this.title,
    this.dueHint,
    this.maxAmount,
    this.initialAmount,
    this.initialNote = '',
  });

  @override
  State<_PurchasePaymentDialog> createState() => _PurchasePaymentDialogState();
}

class _PurchasePaymentDialogState extends State<_PurchasePaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount?.round().toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (widget.maxAmount != null && amount > widget.maxAmount! + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed Rs. ${widget.maxAmount!.round()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _PaymentFormResult(
        amount: amount,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.dueHint != null)
            Text(
              'Due: Rs. ${widget.dueHint!.round()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (widget.dueHint != null) const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofocus: widget.initialAmount == null,
            decoration: const InputDecoration(
              labelText: 'Amount paid (Rs.)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class PurchaseDetailPage extends StatefulWidget {
  final Purchase purchase;

  const PurchaseDetailPage({super.key, required this.purchase});

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  final _storage = StorageService();
  late Purchase _purchase;
  List<PurchasePayment> _payments = [];
  double _paid = 0;
  double _due = 0;
  bool _loading = true;
  String? _modifyBlockedReason;

  @override
  void initState() {
    super.initState();
    _purchase = widget.purchase;
    _load();
  }

  Future<void> _load() async {
    final latest = await _storage.getPurchaseById(_purchase.id);
    if (!mounted) return;
    if (latest == null) {
      Navigator.pop(context, true);
      return;
    }

    final payments = await _storage.getPurchasePayments();
    final paid = await _storage.getPurchasePaidAmount(latest.id);
    final blockReason = await _storage.validatePurchaseCanModify(latest.id);
    if (!mounted) return;
    setState(() {
      _purchase = latest;
      _payments = payments
          .where((payment) => payment.purchaseId == latest.id)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _paid = paid;
      _due = latest.totalAmount - paid;
      _modifyBlockedReason = blockReason;
      _loading = false;
    });
  }

  Future<_PaymentFormResult?> _showPaymentForm({
    required String title,
    double? dueHint,
    double? maxAmount,
    double? initialAmount,
    String initialNote = '',
  }) {
    return showDialog<_PaymentFormResult>(
      context: context,
      builder: (context) => _PurchasePaymentDialog(
        title: title,
        dueHint: dueHint,
        maxAmount: maxAmount,
        initialAmount: initialAmount,
        initialNote: initialNote,
      ),
    );
  }

  Future<void> _editPurchase() async {
    if (_modifyBlockedReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_modifyBlockedReason!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NewPurchasePage(purchaseToEdit: _purchase),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deletePurchase() async {
    if (_modifyBlockedReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_modifyBlockedReason!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final paymentNote = _payments.isEmpty
        ? ''
        : '\n\nThis will also remove ${_payments.length} payment record(s).';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete purchase?'),
        content: Text(
          'Delete purchase of Rs. ${_purchase.totalAmount.round()} '
          'from ${DateFormat('dd MMM yyyy').format(_purchase.date)}?'
          '$paymentNote\n\nStock added by this purchase will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _storage.deletePurchase(_purchase.id);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _addPayment() async {
    final result = await _showPaymentForm(
      title: 'Record payment',
      dueHint: _due,
      maxAmount: _due,
    );
    if (result == null || !mounted) return;

    await _storage.addPurchasePayment(
      PurchasePayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        purchaseId: _purchase.id,
        date: DateTime.now(),
        amount: result.amount,
        note: result.note,
      ),
    );
    await _load();
  }

  Future<void> _editPayment(PurchasePayment payment) async {
    final maxAmount = _due + payment.amount;
    final result = await _showPaymentForm(
      title: 'Edit payment',
      dueHint: _due,
      maxAmount: maxAmount,
      initialAmount: payment.amount,
      initialNote: payment.note,
    );
    if (result == null || !mounted) return;

    await _storage.updatePurchasePayment(
      PurchasePayment(
        id: payment.id,
        purchaseId: payment.purchaseId,
        date: payment.date,
        amount: result.amount,
        note: result.note,
      ),
    );
    await _load();
  }

  Future<void> _deletePayment(PurchasePayment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
          'Remove payment of Rs. ${payment.amount.round()} '
          'from ${DateFormat('dd MMM yyyy').format(payment.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await _storage.deletePurchasePayment(payment.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final purchase = _purchase;
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(purchase.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase details'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: _modifyBlockedReason != null ? Colors.grey : null,
            ),
            tooltip: _modifyBlockedReason != null
                ? 'Cannot edit — stock already sold'
                : 'Edit purchase',
            onPressed: _loading || _modifyBlockedReason != null
                ? null
                : _editPurchase,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: _modifyBlockedReason != null ? Colors.grey : Colors.red,
            ),
            tooltip: _modifyBlockedReason != null
                ? 'Cannot delete — stock already sold'
                : 'Delete purchase',
            onPressed: _loading || _modifyBlockedReason != null
                ? null
                : _deletePurchase,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _due > 0 ? _addPayment : null,
        icon: const Icon(Icons.payments),
        label: const Text('Add payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _due > 0
                          ? [Colors.orange.shade700, Colors.deepOrange.shade600]
                          : [Colors.green.shade700, Colors.teal.shade600],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(
                        'Base price: Rs. ${purchase.basePrice.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total: Rs. ${purchase.totalAmount.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paid: Rs. ${_paid.round()} | Due: Rs. ${_due.round()}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (_modifyBlockedReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_modifyBlockedReason!}\n'
                            'Edit and delete are disabled.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (purchase.note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Note: ${purchase.note}'),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Items purchased',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...purchase.lines.map((line) {
                  final unit = line.unitPriceAtBase(purchase.basePrice);
                  final amount = line.amountAtBase(purchase.basePrice);
                  return Card(
                    child: ListTile(
                      title: Text(
                        StockUtils.itemLabel(line.gauge, line.packing2_5kg),
                      ),
                      subtitle: Text(
                        '${line.weight} kg × Rs. ${unit.round()}/kg '
                        '(base ${purchase.basePrice.round()})',
                      ),
                      trailing: Text(
                        'Rs. ${amount.round()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                const Text(
                  'Payments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No payments yet')),
                  )
                else
                  ..._payments.map(
                    (payment) {
                      final dateLabel = DateFormat('dd MMM yyyy, hh:mm a')
                          .format(payment.date);
                      final noteLabel =
                          payment.note.isEmpty ? dateLabel : '$dateLabel\n${payment.note}';
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.payments,
                            color: Colors.green,
                          ),
                          title: Text('Rs. ${payment.amount.round()}'),
                          subtitle: Text(noteLabel),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                color: Colors.deepPurple,
                                tooltip: 'Edit payment',
                                onPressed: () => _editPayment(payment),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                tooltip: 'Delete payment',
                                onPressed: () => _deletePayment(payment),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
