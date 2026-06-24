import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/storage_service.dart';

class CustomerPickerDialog extends StatefulWidget {
  const CustomerPickerDialog({super.key});

  @override
  State<CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<CustomerPickerDialog> {
  final _storage = StorageService();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<Customer> _customers = [];
  bool _showAddForm = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final customers = await _storage.getCustomers();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  List<Customer> get _filteredCustomers {
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

  Future<void> _saveNewCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer name and WhatsApp number')),
      );
      return;
    }
    final customer = Customer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      whatsappNumber: phone,
    );
    await _storage.upsertCustomer(customer);
    if (!mounted) return;
    Navigator.pop(context, customer);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search customer',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_showAddForm) ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp number',
                        hintText: '10-digit mobile number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showAddForm = false),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _saveNewCustomer,
                          child: const Text('Save & Select'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          _nameController.text = _searchController.text.trim();
                          setState(() => _showAddForm = true);
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add new customer'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: _filteredCustomers.isEmpty
                          ? const Text('No customers found')
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final customer = _filteredCustomers[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(customer.name),
                                  subtitle: Text(customer.whatsappNumber),
                                  onTap: () =>
                                      Navigator.pop(context, customer),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
