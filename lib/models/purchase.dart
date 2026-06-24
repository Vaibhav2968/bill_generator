import '../utils/gauge_utils.dart';

class PurchaseLine {
  final double gauge;
  final double weight;
  final bool packing2_5kg;

  const PurchaseLine({
    required this.gauge,
    required this.weight,
    this.packing2_5kg = false,
  });

  double amountAtBase(double basePrice) => GaugeUtils.calculateAmount(
        basePrice,
        gauge,
        weight,
        packing2_5kg: packing2_5kg,
      );

  double unitPriceAtBase(double basePrice) => GaugeUtils.unitPrice(
        basePrice,
        gauge,
        packing2_5kg: packing2_5kg,
      );

  Map<String, dynamic> toJson() => {
        'gauge': gauge,
        'weight': weight,
        'packing2_5kg': packing2_5kg,
      };

  factory PurchaseLine.fromJson(Map<String, dynamic> json) => PurchaseLine(
        gauge: (json['gauge'] as num).toDouble(),
        weight: (json['weight'] as num).toDouble(),
        packing2_5kg: json['packing2_5kg'] as bool? ?? false,
      );
}

class Purchase {
  final String id;
  final DateTime date;
  final double basePrice;
  final List<PurchaseLine> lines;
  final String note;

  const Purchase({
    required this.id,
    required this.date,
    required this.basePrice,
    required this.lines,
    this.note = '',
  });

  double get totalAmount =>
      lines.fold<double>(0, (sum, line) => sum + line.amountAtBase(basePrice));

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'basePrice': basePrice,
        'lines': lines.map((line) => line.toJson()).toList(),
        'note': note,
      };

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        basePrice: (json['basePrice'] as num).toDouble(),
        lines: (json['lines'] as List<dynamic>)
            .map((e) => PurchaseLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String? ?? '',
      );
}

class PurchasePayment {
  final String id;
  final String purchaseId;
  final DateTime date;
  final double amount;
  final String note;

  const PurchasePayment({
    required this.id,
    required this.purchaseId,
    required this.date,
    required this.amount,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'purchaseId': purchaseId,
        'date': date.toIso8601String(),
        'amount': amount,
        'note': note,
      };

  factory PurchasePayment.fromJson(Map<String, dynamic> json) =>
      PurchasePayment(
        id: json['id'] as String,
        purchaseId: json['purchaseId'] as String,
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String? ?? '',
      );
}
