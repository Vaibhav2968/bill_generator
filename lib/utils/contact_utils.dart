import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickResult {
  final String name;
  final String phone;

  const ContactPickResult({
    required this.name,
    required this.phone,
  });
}

class ContactUtils {
  static Future<bool> requestPermission() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  static Future<List<ContactPickResult>> loadContacts() async {
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    final results = <ContactPickResult>[];
    for (final contact in contacts) {
      final phone = _pickPhone(contact);
      if (phone == null) continue;

      final normalized = normalizeForStorage(phone);
      if (normalized.isEmpty) continue;

      final name = _contactName(contact);
      if (name.isEmpty) continue;

      results.add(ContactPickResult(name: name, phone: normalized));
    }

    results.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return results;
  }

  static String _contactName(Contact contact) {
    return (contact.displayName ?? contact.name?.first ?? '').trim();
  }

  static String? _pickPhone(Contact contact) {
    if (contact.phones.isEmpty) return null;

    for (final phone in contact.phones) {
      if (phone.label.label == PhoneLabel.mobile) {
        return phone.number;
      }
    }
    return contact.phones.first.number;
  }

  static String normalizeForStorage(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    } else if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits.length >= 10 ? digits : '';
  }
}
