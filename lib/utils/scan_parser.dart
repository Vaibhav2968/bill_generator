import 'gauge_utils.dart';

class ScanProductData {
  final double size;
  final double netWeight;
  final String? grade;
  final bool packing2_5kg;

  const ScanProductData({
    required this.size,
    required this.netWeight,
    this.grade,
    this.packing2_5kg = false,
  });
}

class ScanParser {
  static bool _isPackingValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == '2.5' ||
        normalized == '2.5kg' ||
        normalized.contains('2.5');
  }

  static ScanProductData? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    double? size;
    double? net;
    String? grade;
    bool? packingFromBarcode;

    final pattern = RegExp(
      r'([A-Za-z]+)\s*=\s*([^|]+)',
      multiLine: true,
    );

    for (final match in pattern.allMatches(text)) {
      final key = match.group(1)!.trim().toLowerCase();
      final value = match.group(2)!.trim();
      switch (key) {
        case 'size':
          size = double.tryParse(value);
        case 'net':
          net = double.tryParse(value);
        case 'grade':
          grade = value;
        case 'pack':
        case 'packing':
        case 'package':
          packingFromBarcode = _isPackingValue(value);
      }
    }

    if (size == null || net == null || net <= 0) {
      return null;
    }

    final gauge = GaugeUtils.normalizeGauge(size);
    if (gauge == null) {
      return null;
    }

    final packingFromWeight = GaugeUtils.supportsPacking2_5kg(gauge) &&
        GaugeUtils.isLikely2_5KgWeight(net);

    return ScanProductData(
      size: gauge,
      netWeight: net,
      grade: grade,
      packing2_5kg: packingFromBarcode ?? packingFromWeight,
    );
  }
}
