import 'package:flutter/material.dart';

import '../utils/contact_utils.dart';

class ContactPickerPage extends StatefulWidget {
  const ContactPickerPage({super.key});

  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  final _searchController = TextEditingController();
  List<ContactPickResult> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final granted = await ContactUtils.requestPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _loading = false;
        _error = 'Contacts permission is required to pick from your phone.';
      });
      return;
    }

    try {
      final contacts = await ContactUtils.loadContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load contacts. Please try again.';
      });
    }
  }

  List<ContactPickResult> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(query) ||
              contact.phone.contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select contact'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search name or number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.contacts_outlined,
                                size: 48,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadContacts,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text('No contacts with phone numbers found'),
                          )
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final contact = _filtered[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    contact.name.isNotEmpty
                                        ? contact.name[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(contact.name),
                                subtitle: Text(contact.phone),
                                onTap: () =>
                                    Navigator.pop(context, contact),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
