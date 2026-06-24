import 'package:flutter/material.dart';

import '../pages/contact_picker_page.dart';
import '../utils/contact_utils.dart';

class CustomerFormResult {
  final String name;
  final String phone;

  const CustomerFormResult({
    required this.name,
    required this.phone,
  });
}

class CustomerFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhone;

  const CustomerFormDialog({
    super.key,
    required this.title,
    this.initialName,
    this.initialPhone,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    final contact = await Navigator.of(context, rootNavigator: true)
        .push<ContactPickResult>(
      MaterialPageRoute(builder: (context) => const ContactPickerPage()),
    );
    if (!mounted || contact == null) return;

    setState(() {
      _nameController.text = contact.name;
      _phoneController.text = contact.phone;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter customer name and WhatsApp number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      CustomerFormResult(name: name, phone: phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFromContacts,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Pick from contacts'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: '10-digit mobile number',
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
