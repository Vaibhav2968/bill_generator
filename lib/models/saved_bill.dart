import 'bill_stock_line.dart';

class SavedBill {
  final String ledgerEntryId;
  final String customerId;
  final DateTime date;
  final String billNumber;
  final String billDetails;
  final String billDetailsFormatted;
  final String total;
  final String price;
  final String weight;
  final String amount;
  final String gauge;
  final double totalAmount;
  final double totalWeight;
  final List<BillStockLine> lineItems;

  const SavedBill({
    required this.ledgerEntryId,
    required this.customerId,
    required this.date,
    this.billNumber = '',
    required this.billDetails,
    required this.billDetailsFormatted,
    required this.total,
    required this.price,
    required this.weight,
    required this.amount,
    required this.gauge,
    required this.totalAmount,
    required this.totalWeight,
    this.lineItems = const [],
  });

  SavedBill copyWith({
    String? billNumber,
    String? billDetails,
    String? billDetailsFormatted,
    String? total,
    String? price,
    String? weight,
    String? amount,
    String? gauge,
    double? totalAmount,
    double? totalWeight,
    List<BillStockLine>? lineItems,
  }) {
    return SavedBill(
      ledgerEntryId: ledgerEntryId,
      customerId: customerId,
      date: date,
      billNumber: billNumber ?? this.billNumber,
      billDetails: billDetails ?? this.billDetails,
      billDetailsFormatted: billDetailsFormatted ?? this.billDetailsFormatted,
      total: total ?? this.total,
      price: price ?? this.price,
      weight: weight ?? this.weight,
      amount: amount ?? this.amount,
      gauge: gauge ?? this.gauge,
      totalAmount: totalAmount ?? this.totalAmount,
      totalWeight: totalWeight ?? this.totalWeight,
      lineItems: lineItems ?? this.lineItems,
    );
  }

  Map<String, dynamic> toJson() => {
        'ledgerEntryId': ledgerEntryId,
        'customerId': customerId,
        'date': date.toIso8601String(),
        'billNumber': billNumber,
        'billDetails': billDetails,
        'billDetailsFormatted': billDetailsFormatted,
        'total': total,
        'price': price,
        'weight': weight,
        'amount': amount,
        'gauge': gauge,
        'totalAmount': totalAmount,
        'totalWeight': totalWeight,
        'lineItems': lineItems.map((e) => e.toJson()).toList(),
      };

  factory SavedBill.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lineItems'] as List<dynamic>?;
    final lines = rawLines == null
        ? <BillStockLine>[]
        : rawLines
            .map((e) => BillStockLine.fromJson(e as Map<String, dynamic>))
            .toList();

    return SavedBill(
        ledgerEntryId: json['ledgerEntryId'] as String,
        customerId: json['customerId'] as String,
        date: DateTime.parse(json['date'] as String),
        billNumber: json['billNumber'] as String? ?? '',
        billDetails: json['billDetails'] as String,
        billDetailsFormatted: json['billDetailsFormatted'] as String,
        total: json['total'] as String,
        price: json['price'] as String,
        weight: json['weight'] as String,
        amount: json['amount'] as String,
        gauge: json['gauge'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        totalWeight: (json['totalWeight'] as num).toDouble(),
        lineItems: lines,
      );
  }
}
