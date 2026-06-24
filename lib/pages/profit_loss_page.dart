import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/profit_summary.dart';
import '../services/profit_service.dart';
import '../services/storage_service.dart';

class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});

  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  final _storage = StorageService();
  final _profitService = ProfitService();

  bool _monthlyMode = false;
  DateTime? _selectedMonth;
  List<DateTime> _months = [];
  ProfitSummary? _summary;
  double _overallDue = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final months = await _profitService.availableMonths();
    final dueSummary = await _storage.getDueSummary();
    final month = _selectedMonth ??
        (months.isNotEmpty ? months.first : DateTime.now());

    if (_selectedMonth == null && months.isNotEmpty) {
      _selectedMonth = months.first;
    }

    final summary = await _profitService.calculateSummary(
      month: _monthlyMode ? month : null,
    );

    if (!mounted) return;
    setState(() {
      _months = months;
      _selectedMonth = _monthlyMode ? month : null;
      _summary = summary;
      _overallDue = dueSummary.totalDue;
      _loading = false;
    });
  }

  String get _periodLabel {
    if (!_monthlyMode) return 'All time';
    if (_selectedMonth == null) return 'Monthly';
    return DateFormat('MMMM yyyy').format(_selectedMonth!);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('All'),
                          icon: Icon(Icons.all_inclusive),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Monthly'),
                          icon: Icon(Icons.calendar_month),
                        ),
                      ],
                      selected: {_monthlyMode},
                      onSelectionChanged: (value) {
                        setState(() {
                          _monthlyMode = value.first;
                        });
                        _load();
                      },
                    ),
                    if (_monthlyMode) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DateTime>(
                        value: _months.contains(_selectedMonth)
                            ? _selectedMonth
                            : (_months.isNotEmpty ? _months.first : null),
                        decoration: const InputDecoration(
                          labelText: 'Select month',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _months
                            .map(
                              (month) => DropdownMenuItem(
                                value: month,
                                child: Text(
                                  DateFormat('MMMM yyyy').format(month),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _months.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedMonth = value;
                                });
                                _load();
                              },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: const Text(
                        'Profit = bill sales − purchase cost from stock.\n'
                        'Add stock with your buy rate. Bills use your selling base price.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (summary != null) ...[
                      _buildProfitHero(summary),
                      const SizedBox(height: 16),
                      _buildMetricCard(
                        title: 'Total sales',
                        value: 'Rs. ${summary.totalSales.round()}',
                        subtitle:
                            '${summary.billCount} bill${summary.billCount == 1 ? '' : 's'} | '
                            '${summary.totalWeightSold.toStringAsFixed(3)} kg sold',
                        icon: Icons.receipt_long,
                        color: Colors.blue,
                      ),
                      _buildMetricCard(
                        title: 'Purchase cost (from stock)',
                        value: 'Rs. ${summary.costOfGoodsSold.round()}',
                        subtitle: 'Based on base price when stock was added',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.orange,
                      ),
                      _buildMetricCard(
                        title: 'Payments collected',
                        value: 'Rs. ${summary.totalPayments.round()}',
                        subtitle:
                            '${summary.paymentCount} payment${summary.paymentCount == 1 ? '' : 's'} in $_periodLabel',
                        icon: Icons.payments,
                        color: Colors.green,
                      ),
                      if (!_monthlyMode)
                        _buildMetricCard(
                          title: 'Pending to collect',
                          value: 'Rs. ${_overallDue.round()}',
                          subtitle: 'Overall due from all customers',
                          icon: Icons.account_balance_wallet,
                          color: Colors.deepOrange,
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No data yet')),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfitHero(ProfitSummary summary) {
    final isProfit = summary.isProfit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [Colors.green.shade700, Colors.teal.shade600]
              : [Colors.red.shade700, Colors.deepOrange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            isProfit ? 'Gross Profit' : 'Gross Loss',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${summary.grossProfit.abs().round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isProfit ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isProfit
                      ? 'Selling price is above your stock purchase cost'
                      : 'Selling price is below your stock purchase cost',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ),
    );
  }
}
