import 'package:url_launcher/url_launcher.dart';

class WhatsAppUtils {
  static String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  static Future<bool> shareText({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.parse(
      'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
