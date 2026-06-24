class Customer {
  final String id;
  final String name;
  final String whatsappNumber;

  const Customer({
    required this.id,
    required this.name,
    required this.whatsappNumber,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'whatsappNumber': whatsappNumber,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        whatsappNumber: json['whatsappNumber'] as String,
      );

  Customer copyWith({
    String? id,
    String? name,
    String? whatsappNumber,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      );
}
