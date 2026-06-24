class BillStockLine {
  final double gauge;
  final double weight;
  final bool packing2_5kg;

  const BillStockLine({
    required this.gauge,
    required this.weight,
    this.packing2_5kg = false,
  });

  Map<String, dynamic> toJson() => {
        'gauge': gauge,
        'weight': weight,
        'packing2_5kg': packing2_5kg,
      };

  factory BillStockLine.fromJson(Map<String, dynamic> json) => BillStockLine(
        gauge: (json['gauge'] as num).toDouble(),
        weight: (json['weight'] as num).toDouble(),
        packing2_5kg: json['packing2_5kg'] as bool? ?? false,
      );
}
