import '../utils/gauge_utils.dart';

class StockEntry {
  final String id;
  final DateTime date;
  final double gauge;
  final double weight;
  final bool packing2_5kg;
  final double basePrice;
  final String type; // 'in' or 'out'
  final String source; // 'purchase', 'scan', 'bill', 'manual'
  final String note;
  final String? linkedBillId;
  final String? linkedPurchaseId;

  const StockEntry({
    required this.id,
    required this.date,
    required this.gauge,
    required this.weight,
    this.packing2_5kg = false,
    required this.basePrice,
    this.type = 'in',
    this.source = 'manual',
    this.note = '',
    this.linkedBillId,
    this.linkedPurchaseId,
  });

  bool get isIncoming => type == 'in';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'gauge': gauge,
        'weight': weight,
        'packing2_5kg': packing2_5kg,
        'basePrice': basePrice,
        'type': type,
        'source': source,
        'note': note,
        'linkedBillId': linkedBillId,
        'linkedPurchaseId': linkedPurchaseId,
      };

  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        gauge: (json['gauge'] as num).toDouble(),
        weight: (json['weight'] as num).toDouble(),
        packing2_5kg: json['packing2_5kg'] as bool? ?? false,
        basePrice: (json['basePrice'] as num).toDouble(),
        type: json['type'] as String? ?? 'in',
        source: json['source'] as String? ?? 'manual',
        note: json['note'] as String? ?? '',
        linkedBillId: json['linkedBillId'] as String?,
        linkedPurchaseId: json['linkedPurchaseId'] as String?,
      );
}

class StockSummaryItem {
  final double gauge;
  final bool packing2_5kg;
  final double weight;

  const StockSummaryItem({
    required this.gauge,
    required this.packing2_5kg,
    required this.weight,
  });

  double stockValue(double basePrice) =>
      GaugeUtils.unitPrice(basePrice, gauge, packing2_5kg: packing2_5kg) *
      weight;
}

class StockBatch {
  final String sourceEntryId;
  final double remainingWeight;
  final double addedWeight;
  final double basePrice;
  final DateTime date;

  const StockBatch({
    required this.sourceEntryId,
    required this.remainingWeight,
    required this.addedWeight,
    required this.basePrice,
    required this.date,
  });

  bool get isPartiallyUsed =>
      remainingWeight < addedWeight - 0.001;

  double buyRate(double gauge, {bool packing2_5kg = false}) =>
      GaugeUtils.unitPrice(basePrice, gauge, packing2_5kg: packing2_5kg);
}

class StockBaseBreakdown {
  final double basePrice;
  final double weight;

  const StockBaseBreakdown({
    required this.basePrice,
    required this.weight,
  });
}
