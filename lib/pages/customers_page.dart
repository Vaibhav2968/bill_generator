import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/storage_service.dart';
import '../widgets/customer_form_dialog.dart';
import '../widgets/due_summary_card.dart';
import 'customer_ledger_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _storage = StorageService();
  final _searchController = TextEditingController();
  List<Customer> _customers = [];
  Map<String, double> _balances = {};
  double _totalDue = 0;
  int _customersWithDue = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final customers = await _storage.getCustomers();
    final summary = await _storage.getDueSummary();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _balances = summary.balances;
      _totalDue = summary.totalDue;
      _customersWithDue = summary.customersWithDue;
      _loading = false;
    });
  }

  List<Customer> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _customers;
    return _customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(query) ||
              c.whatsappNumber.contains(query),
        )
        .toList();
  }

  Future<void> _addOrEditCustomer([Customer? existing]) async {
    final result = await showDialog<CustomerFormResult>(
      context: context,
      builder: (context) => CustomerFormDialog(
        title: existing == null ? 'Add Customer' : 'Edit Customer',
        initialName: existing?.name,
        initialPhone: existing?.whatsappNumber,
      ),
    );
    if (result == null || !mounted) return;

    await _storage.upsertCustomer(
      Customer(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.name,
        whatsappNumber: result.phone,
      ),
    );
    await _load();
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('Remove ${customer.name} from your customer list?'),
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
    await _storage.deleteCustomer(customer.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCustomer(),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                DueSummaryCard(
                  amount: _totalDue,
                  title: 'Total to Collect',
                  subtitle: _customersWithDue == 0
                      ? 'No pending dues from customers'
                      : _customersWithDue == 1
                          ? 'From 1 customer with pending due'
                          : 'From $_customersWithDue customers with pending due',
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or number',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('No customers yet'))
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final customer = _filtered[index];
                            final balance = _balances[customer.id] ?? 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${customer.whatsappNumber}\nDue: Rs. ${balance.round()}',
                                ),
                                isThreeLine: true,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CustomerLedgerPage(
                                        customer: customer,
                                      ),
                                    ),
                                  );
                                  await _load();
                                },
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _addOrEditCustomer(customer);
                                    } else if (value == 'delete') {
                                      _deleteCustomer(customer);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
