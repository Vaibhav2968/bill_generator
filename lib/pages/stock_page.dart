import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/purchase.dart';
import '../models/stock_entry.dart';
import '../pages/new_purchase_page.dart';
import '../pages/purchase_detail_page.dart';
import '../services/storage_service.dart';
import '../utils/gauge_utils.dart';
import '../utils/stock_utils.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  late final TabController _tabController;

  List<StockEntry> _entries = [];
  List<StockSummaryItem> _summary = [];
  List<Purchase> _purchases = [];
  Map<String, double> _purchaseDue = {};
  double _stockValue = 0;
  double _totalPurchaseDue = 0;
  double _lastBasePrice = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await _storage.getStockEntries();
    final purchases = await _storage.getPurchases();
    final lastBase = await _storage.getStockBasePrice();
    final totalDue = await _storage.getTotalPurchaseDue();
    entries.sort((a, b) => b.date.compareTo(a.date));

    final dueMap = <String, double>{};
    for (final purchase in purchases) {
      dueMap[purchase.id] = await _storage.getPurchaseDue(purchase.id);
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _summary = _storage.buildStockSummary(entries);
      _stockValue = _storage.calculateStockValueFromEntries(entries);
      _purchases = purchases;
      _purchaseDue = dueMap;
      _totalPurchaseDue = totalDue;
      _lastBasePrice = lastBase;
      _loading = false;
    });
  }

  Future<void> _openNewPurchase() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NewPurchasePage(lastBasePrice: _lastBasePrice),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _removeStockManual() async {
    double? gauge;
    bool packing = false;
    final weightController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remove stock'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<double>(
                      value: gauge,
                      decoration: const InputDecoration(
                        labelText: 'Gauge',
                        border: OutlineInputBorder(),
                      ),
                      items: GaugeUtils.gaugeDropdownItems(),
                      onChanged: (value) {
                        setDialogState(() {
                          gauge = value;
                          if (value == null ||
                              !GaugeUtils.supportsPacking2_5kg(value)) {
                            packing = false;
                          }
                        });
                      },
                    ),
                    if (gauge != null &&
                        GaugeUtils.supportsPacking2_5kg(gauge!))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('2.5 kg packing'),
                        value: packing,
                        onChanged: (value) {
                          setDialogState(() => packing = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );

    final weight = double.tryParse(weightController.text.trim());
    weightController.dispose();
    if (saved != true || gauge == null || weight == null || weight <= 0) return;

    final normalized = GaugeUtils.normalizeGauge(gauge!) ?? gauge!;
    final available = _summary
        .where(
          (item) =>
              item.gauge == normalized && item.packing2_5kg == packing,
        )
        .fold<double>(0, (sum, item) => sum + item.weight);

    if (weight > available + 0.001) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${available.toStringAsFixed(3)} kg available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final avgBase = _storage.averagePurchaseBaseForSku(
      _entries,
      normalized,
      packing,
    );

    await _storage.addStockEntry(
      StockEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        gauge: normalized,
        weight: weight,
        packing2_5kg: packing,
        basePrice: avgBase,
        type: 'out',
        source: 'manual',
        note: 'Manual removal',
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight = _storage.totalStockWeight(_summary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock & Purchases'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stock'),
            Tab(text: 'Purchases'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPurchase,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Purchase'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStockTab(totalWeight),
                _buildPurchasesTab(),
              ],
            ),
    );
  }

  Widget _buildStockTab(double totalWeight) {
    final bottomPad = MediaQuery.paddingOf(context).bottom + 88;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
        children: [
          _buildSummaryCard(
            title: 'Total Stock',
            amount: '${totalWeight.toStringAsFixed(3)} kg',
            subtitle: 'Value at buy rates: Rs. ${_stockValue.round()}',
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            title: 'Purchase due to pay',
            amount: 'Rs. ${_totalPurchaseDue.round()}',
            subtitle: 'Unpaid supplier amount',
            color: Colors.orange.shade800,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _removeStockManual,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Manual stock removal'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Current stock',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_summary.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No stock yet. Add a purchase.')),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: _summary.length,
              itemBuilder: (context, index) =>
                  _buildStockGridTile(_summary[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab() {
    final bottomPad = MediaQuery.paddingOf(context).bottom + 88;
    return RefreshIndicator(
      onRefresh: _load,
      child: _purchases.isEmpty
          ? ListView(
              padding: EdgeInsets.only(bottom: bottomPad),
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No purchases yet')),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
              itemCount: _purchases.length,
              itemBuilder: (context, index) {
                final purchase = _purchases[index];
                final due = _purchaseDue[purchase.id] ?? 0;
                final date =
                    DateFormat('dd MMM yyyy').format(purchase.date);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        purchase.basePrice.round().toString(),
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    title: Text(
                      'Rs. ${purchase.totalAmount.round()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$date | Base Rs. ${purchase.basePrice.round()} | '
                      '${purchase.lines.length} item(s)\n'
                      'Due: Rs. ${due.round()}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PurchaseDetailPage(purchase: purchase),
                        ),
                      );
                      if (changed == true) {
                        await _load();
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  void _openStockDetail(StockSummaryItem item) {
    final batches = _storage.getRemainingStockBatches(
      _entries,
      item.gauge,
      item.packing2_5kg,
    );
    final label = StockUtils.itemLabel(item.gauge, item.packing2_5kg);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${item.weight.toStringAsFixed(3)} kg',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Individual lots in stock',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final date =
                        DateFormat('dd MMM yyyy').format(batch.date);
                    final weightText = batch.isPartiallyUsed
                        ? '${batch.remainingWeight.toStringAsFixed(3)} kg left '
                          '(added ${batch.addedWeight.toStringAsFixed(3)} kg)'
                        : '${batch.remainingWeight.toStringAsFixed(3)} kg';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        weightText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '$date | Base Rs. ${batch.basePrice.round()}',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total in stock',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${item.weight.toStringAsFixed(3)} kg',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockGridTile(StockSummaryItem item) {
    final gaugeLabel = GaugeUtils.formatGaugeLabel(item.gauge);

    return InkWell(
      onTap: () => _openStockDetail(item),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  gaugeLabel,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ),
              const Text(
                'swg',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (item.packing2_5kg)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '2.5kg',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${item.weight.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
