class LedgerEntry {
  final String id;
  final String customerId;
  final DateTime date;
  final String type; // 'bill' or 'payment'
  final double amount;
  final String note;

  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.date,
    required this.type,
    required this.amount,
    this.note = '',
  });

  bool get isBill => type == 'bill';
  bool get isPayment => type == 'payment';

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'date': date.toIso8601String(),
        'type': type,
        'amount': amount,
        'note': note,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        date: DateTime.parse(json['date'] as String),
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String? ?? '',
      );
}
