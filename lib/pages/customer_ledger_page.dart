import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../pages/bill_page.dart';
import '../services/storage_service.dart';
import '../utils/whatsapp_utils.dart';
import '../widgets/due_summary_card.dart';

class CustomerLedgerPage extends StatefulWidget {
  final Customer customer;

  const CustomerLedgerPage({super.key, required this.customer});

  @override
  State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  final _storage = StorageService();
  List<LedgerEntry> _entries = [];
  double _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.getLedgerForCustomer(widget.customer.id);
    final balance = await _storage.getCustomerBalance(widget.customer.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _balance = balance;
      _loading = false;
    });
  }

  List<DateTime> get _availableMonths {
    final months = <String, DateTime>{};
    for (final entry in _entries) {
      final key = '${entry.date.year}-${entry.date.month}';
      months[key] = DateTime(entry.date.year, entry.date.month);
    }
    final list = months.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<LedgerEntry> _entriesForMonth(DateTime month) {
    return _entries
        .where(
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        )
        .toList();
  }

  String _buildLedgerText({
    List<LedgerEntry>? entries,
    DateTime? month,
    bool includeOverallDue = true,
  }) {
    final shareEntries = entries ?? _entries;
    final buffer = StringBuffer()
      ..writeln('LEDGER STATEMENT')
      ..writeln('Customer: ${widget.customer.name}');

    if (month != null) {
      final monthLabel = DateFormat('MMMM yyyy').format(month);
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      buffer
        ..writeln('Period: $monthLabel')
        ..writeln(
          'From: ${DateFormat('dd MMM yyyy').format(month)}',
        )
        ..writeln(
          'To: ${DateFormat('dd MMM yyyy').format(DateTime(month.year, month.month, lastDay))}',
        );
    } else {
      buffer.writeln(
        'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      );
    }

    buffer.writeln('');

    if (shareEntries.isEmpty) {
      buffer.writeln('No transactions in this period.');
    } else {
      buffer.writeln('Transactions:');
      final sorted = shareEntries.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      double monthBills = 0;
      double monthPayments = 0;

      for (final entry in sorted) {
        final date = DateFormat('dd MMM yyyy').format(entry.date);
        if (entry.isBill) {
          monthBills += entry.amount;
          final label =
              entry.note.isNotEmpty ? 'Bill ${entry.note}' : 'Bill';
          buffer.writeln('$date | $label | +Rs. ${entry.amount.round()}');
        } else {
          monthPayments += entry.amount;
          buffer.writeln('$date | Payment | -Rs. ${entry.amount.round()}');
        }
        if (entry.note.isNotEmpty && entry.isPayment) {
          buffer.writeln('  ${entry.note}');
        }
      }

      if (month != null) {
        buffer
          ..writeln('')
          ..writeln('Month total bills: Rs. ${monthBills.round()}')
          ..writeln('Month total payments: Rs. ${monthPayments.round()}')
          ..writeln(
            'Month net: Rs. ${(monthBills - monthPayments).round()}',
          );
      }
    }

    if (includeOverallDue) {
      buffer
        ..writeln('')
        ..writeln('Overall due balance: Rs. ${_balance.round()}');
    }

    return buffer.toString().trim();
  }

  Future<void> _sendLedgerText(String text) async {
    final opened = await WhatsAppUtils.shareText(
      phone: widget.customer.whatsappNumber,
      message: text,
    );
    if (!opened && mounted) {
      await Share.share(text);
    }
  }

  Future<void> _shareMonthlyLedger(DateTime month) async {
    final entries = _entriesForMonth(month);
    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No transactions in ${DateFormat('MMMM yyyy').format(month)}',
          ),
        ),
      );
      return;
    }

    await _sendLedgerText(
      _buildLedgerText(entries: entries, month: month),
    );
  }

  Future<void> _showShareOptions() async {
    final months = _availableMonths;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Share Ledger',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose what to send on WhatsApp',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.deepPurple),
                title: const Text('Full ledger'),
                subtitle: const Text('All transactions till today'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _sendLedgerText(_buildLedgerText());
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.teal),
                title: const Text('Monthly statement'),
                subtitle: Text(
                  months.isEmpty
                      ? 'No monthly data yet'
                      : 'Pick a month to share',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onTap: months.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        _showMonthPicker(months);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMonthPicker(List<DateTime> months) async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select month',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final month = months[index];
                  final label = DateFormat('MMMM yyyy').format(month);
                  final count = _entriesForMonth(month).length;
                  return ListTile(
                    leading: const Icon(Icons.date_range),
                    title: Text(label),
                    subtitle: Text('$count transaction${count == 1 ? '' : 's'}'),
                    onTap: () => Navigator.pop(context, month),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await _shareMonthlyLedger(selected);
    }
  }

  Future<void> _shareLedger() async {
    await _showShareOptions();
  }

  Future<void> _openBill(LedgerEntry entry) async {
    final saved = await _storage.getSavedBill(entry.id);
    if (saved == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bill details not available for older entries. Create a new bill to save full details.',
          ),
        ),
      );
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BillPage.fromSaved(saved, widget.customer),
      ),
    );

    await _load();
  }

  Future<void> _showPaymentDialog({LedgerEntry? existing}) async {
    final isEdit = existing != null;
    final amountController = TextEditingController(
      text: isEdit ? existing.amount.round().toString() : '',
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    final controllers = [amountController, noteController];

    final result = await showDialog<({double amount, String note})?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Payment' : 'Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(existing.date),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount collected (Rs.)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
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
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(
                context,
                (amount: amount, note: noteController.text.trim()),
              );
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    if (result == null) return;

    if (isEdit) {
      await _storage.updateLedgerEntry(
        LedgerEntry(
          id: existing.id,
          customerId: existing.customerId,
          date: existing.date,
          type: 'payment',
          amount: result.amount,
          note: result.note,
        ),
      );
    } else {
      await _storage.addLedgerEntry(
        LedgerEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          customerId: widget.customer.id,
          date: DateTime.now(),
          type: 'payment',
          amount: result.amount,
          note: result.note,
        ),
      );
    }

    await _load();
  }

  Future<void> _openPayment(LedgerEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment received',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(entry.date),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: Rs. ${entry.amount.round()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Note: ${entry.note}'),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPaymentDialog(existing: entry);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deletePayment(entry);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePayment(LedgerEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
          'Remove payment of Rs. ${entry.amount.round()}? Due balance will be updated.',
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

    await _storage.deletePaymentEntry(entry.id);
    await _load();
  }

  Future<void> _addPayment() async {
    await _showPaymentDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        actions: [
          IconButton(
            onPressed: _shareLedger,
            icon: const Icon(Icons.share),
            tooltip: 'Share ledger',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPayment,
        icon: const Icon(Icons.payments),
        label: const Text('Record Payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                DueSummaryCard(
                  amount: _balance,
                  title: 'Due from ${widget.customer.name}',
                  subtitle: _balance > 0
                      ? 'Amount to collect from this customer'
                      : 'No pending due from this customer',
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('No transactions yet'))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final isBill = entry.isBill;
                            return ListTile(
                              leading: Icon(
                                isBill ? Icons.receipt_long : Icons.payments,
                                color: isBill ? Colors.red : Colors.green,
                              ),
                              title: Text(
                                isBill
                                    ? (entry.note.isNotEmpty
                                        ? 'Bill ${entry.note}'
                                        : 'Bill')
                                    : 'Payment received',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${DateFormat('dd MMM yyyy, hh:mm a').format(entry.date)}'
                                '${entry.note.isNotEmpty ? '\n${entry.note}' : ''}'
                                '\nTap to ${isBill ? 'view bill' : 'view payment'}',
                              ),
                              trailing: Text(
                                '${isBill ? '+' : '-'}Rs. ${entry.amount.round()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isBill ? Colors.red : Colors.green,
                                ),
                              ),
                              onTap: () =>
                                  isBill ? _openBill(entry) : _openPayment(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
