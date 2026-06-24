class BillNumberUtils {
  /// Indian FY: April to March. Returns suffix like 2627 for Apr 2026 - Mar 2027.
  static String financialYearSuffix(DateTime date) {
    final year = date.year;
    final month = date.month;
    if (month >= 4) {
      final start = year % 100;
      final end = (year + 1) % 100;
      return '$start${end.toString().padLeft(2, '0')}';
    }
    final start = (year - 1) % 100;
    final end = year % 100;
    return '${start.toString().padLeft(2, '0')}${end.toString().padLeft(2, '0')}';
  }

  static String financialYearLabel(DateTime date) {
    final suffix = financialYearSuffix(date);
    if (suffix.length != 4) return suffix;
    return '20${suffix.substring(0, 2)}-20${suffix.substring(2, 4)}';
  }

  static String format(int sequence, DateTime date) =>
      '$sequence-${financialYearSuffix(date)}';

  static ({int sequence, String fySuffix})? parse(String billNumber) {
    final match = RegExp(r'^(\d+)\s*-\s*(\d{4})$').firstMatch(billNumber.trim());
    if (match == null) return null;
    return (
      sequence: int.parse(match.group(1)!),
      fySuffix: match.group(2)!,
    );
  }

  static String normalize(String billNumber, DateTime date) {
    final parsed = parse(billNumber);
    if (parsed == null) {
      return billNumber.trim();
    }
    return '${parsed.sequence}-${parsed.fySuffix}';
  }

  static bool isValid(String billNumber, DateTime date) {
    final parsed = parse(billNumber);
    if (parsed == null) return false;
    return parsed.fySuffix == financialYearSuffix(date);
  }
}
