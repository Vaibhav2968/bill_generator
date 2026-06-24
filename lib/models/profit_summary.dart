class ProfitSummary {
  final double totalSales;
  final double totalPayments;
  final double costOfGoodsSold;
  final double grossProfit;
  final int billCount;
  final int paymentCount;
  final double totalWeightSold;

  const ProfitSummary({
    required this.totalSales,
    required this.totalPayments,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.billCount,
    required this.paymentCount,
    required this.totalWeightSold,
  });

  bool get isProfit => grossProfit >= 0;
}
