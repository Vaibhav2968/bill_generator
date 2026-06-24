import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stock_entry.dart';
import '../pages/scan_page.dart';
import '../services/storage_service.dart';
import '../utils/gauge_utils.dart';
import '../utils/scan_parser.dart';
import '../utils/stock_utils.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _storage = StorageService();
  final _basePriceController = TextEditingController();
  final _weightController = TextEditingController();

  List<StockEntry> _entries = [];
  List<StockSummaryItem> _summary = [];
  double _basePrice = 0;
  bool _loading = true;

  double? _selectedGauge;
  bool _selectedPacking2_5kg = false;
  bool _removeMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _basePriceController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await _storage.getStockEntries();
    final basePrice = await _storage.getStockBasePrice();
    entries.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _basePrice = basePrice;
      _basePriceController.text =
          basePrice > 0 ? basePrice.round().toString() : '';
      _summary = _storage.buildStockSummary(entries);
      _loading = false;
    });
  }

  Future<void> _saveBasePrice() async {
    final price = double.tryParse(_basePriceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid base price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _storage.setStockBasePrice(price);
    setState(() {
      _basePrice = price;
      _summary = _storage.buildStockSummary(_entries);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase base price saved')),
    );
  }

  Future<void> _addStock({
    required double gauge,
    required double weight,
    bool packing2_5kg = false,
    String source = 'manual',
    String type = 'in',
  }) async {
    if (_basePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save purchase base price first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final normalized = GaugeUtils.normalizeGauge(gauge);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid gauge size'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (type == 'out') {
      final current = _summary
          .where(
            (item) =>
                item.gauge == normalized &&
                item.packing2_5kg == packing2_5kg,
          )
          .fold<double>(0, (sum, item) => sum + item.weight);
      if (weight > current + 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only ${current.toStringAsFixed(3)} kg available for '
              '${StockUtils.itemLabel(normalized, packing2_5kg)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    await _storage.addStockEntry(
      StockEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        gauge: normalized,
        weight: weight,
        packing2_5kg: packing2_5kg,
        basePrice: _basePrice,
        type: type,
        source: source,
      ),
    );
    await _load();
  }

  Future<void> _submitManualEntry() async {
    final weight = double.tryParse(_weightController.text.trim());
    if (_selectedGauge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a gauge'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid weight'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _addStock(
      gauge: _selectedGauge!,
      weight: weight,
      packing2_5kg: _selectedPacking2_5kg,
      type: _removeMode ? 'out' : 'in',
    );

    setState(() {
      _weightController.clear();
      if (!_removeMode) {
        _selectedGauge = null;
        _selectedPacking2_5kg = false;
      }
    });
  }

  Future<void> _openScanner() async {
    if (_basePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save purchase base price before scanning'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = await Navigator.push<ScanProductData>(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );
    if (!mounted || data == null) return;

    final gauge = GaugeUtils.normalizeGauge(data.size);
    if (gauge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid gauge from scan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _addStock(
      gauge: gauge,
      weight: data.netWeight,
      packing2_5kg: data.packing2_5kg,
      source: 'scan',
      type: _removeMode ? 'out' : 'in',
    );

    if (!mounted) return;
    final action = _removeMode ? 'Removed' : 'Added';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action ${data.netWeight} kg | '
          '${StockUtils.itemLabel(gauge, data.packing2_5kg)}',
        ),
        backgroundColor: _removeMode ? Colors.orange.shade800 : Colors.teal.shade700,
      ),
    );
  }

  Future<void> _deleteEntry(StockEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete stock entry?'),
        content: Text(
          '${entry.isIncoming ? 'Added' : 'Removed'} '
          '${entry.weight} kg | '
          '${StockUtils.itemLabel(entry.gauge, entry.packing2_5kg)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _storage.deleteStockEntry(entry.id);
    await _load();
  }

  Future<void> _editEntry(StockEntry entry) async {
    double? editGauge = entry.gauge;
    bool editPacking = entry.packing2_5kg;
    final weightController =
        TextEditingController(text: entry.weight.toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit stock entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<double>(
                      value: editGauge,
                      decoration: const InputDecoration(
                        labelText: 'Gauge',
                        border: OutlineInputBorder(),
                      ),
                      items: GaugeUtils.gaugeDropdownItems(),
                      onChanged: (value) {
                        setDialogState(() {
                          editGauge = value;
                          if (value == null ||
                              !GaugeUtils.supportsPacking2_5kg(value)) {
                            editPacking = false;
                          }
                        });
                      },
                    ),
                    if (editGauge != null &&
                        GaugeUtils.supportsPacking2_5kg(editGauge!)) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('2.5 kg packing'),
                        value: editPacking,
                        onChanged: (value) {
                          setDialogState(() {
                            editPacking = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
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
                TextButton(
                  onPressed: () {
                    final weight =
                        double.tryParse(weightController.text.trim());
                    if (editGauge == null || weight == null || weight <= 0) {
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      final weight = double.tryParse(weightController.text.trim());
      if (editGauge != null && weight != null && weight > 0) {
        await _storage.updateStockEntry(
          StockEntry(
            id: entry.id,
            date: entry.date,
            gauge: editGauge!,
            weight: weight,
            packing2_5kg: editPacking,
            basePrice: entry.basePrice,
            type: entry.type,
            source: entry.source,
            note: entry.note,
          ),
        );
        await _load();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      weightController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight = _storage.totalStockWeight(_summary);
    final totalValue = _storage.totalStockValue(_summary, _basePrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
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
                    _buildSummaryCard(
                      title: 'Total Stock',
                      amount: '${totalWeight.toStringAsFixed(3)} kg',
                      subtitle: _basePrice > 0
                          ? 'Estimated value: Rs. ${totalValue.round()}'
                          : 'Set purchase base price to see stock value',
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _basePriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Purchase base price (Rs.)',
                        hintText: 'Rate you buy wire at',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          onPressed: _saveBasePrice,
                          icon: const Icon(Icons.save),
                          tooltip: 'Save base price',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _removeMode ? 'Remove stock' : 'Add stock',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FilterChip(
                          label: Text(_removeMode ? 'Remove mode' : 'Add mode'),
                          selected: _removeMode,
                          onSelected: (value) {
                            setState(() {
                              _removeMode = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<double>(
                      value: _selectedGauge,
                      decoration: const InputDecoration(
                        labelText: 'Select gauge',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      isExpanded: true,
                      items: GaugeUtils.gaugeDropdownItems(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGauge = value;
                          if (value == null ||
                              !GaugeUtils.supportsPacking2_5kg(value)) {
                            _selectedPacking2_5kg = false;
                          }
                        });
                      },
                    ),
                    if (_selectedGauge != null &&
                        GaugeUtils.supportsPacking2_5kg(_selectedGauge!))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('2.5 kg packing'),
                        value: _selectedPacking2_5kg,
                        onChanged: (value) {
                          setState(() {
                            _selectedPacking2_5kg = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitManualEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _removeMode ? Colors.orange : Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_removeMode ? 'Remove' : 'Add'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Current stock',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_summary.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No stock added yet'),
                        ),
                      )
                    else
                      ..._summary.map(_buildSummaryTile),
                    const SizedBox(height: 24),
                    const Text(
                      'Recent movements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('No movements yet')),
                      )
                    else
                      ..._entries.take(30).map(_buildMovementTile),
                  ],
                ),
              ),
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
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(StockSummaryItem item) {
    final unitPrice = GaugeUtils.unitPrice(
      _basePrice,
      item.gauge,
      packing2_5kg: item.packing2_5kg,
    );
    final value = item.stockValue(_basePrice);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Text(
            GaugeUtils.formatGaugeLabel(item.gauge),
            style: TextStyle(
              color: Colors.teal.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          StockUtils.itemLabel(item.gauge, item.packing2_5kg),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _basePrice > 0
              ? 'Price: Rs. ${unitPrice.round()}/kg | Value: Rs. ${value.round()}'
              : 'In stock',
        ),
        trailing: Text(
          '${item.weight.toStringAsFixed(3)} kg',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMovementTile(StockEntry entry) {
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(entry.date);
    final isIn = entry.isIncoming;
    final isBillLinked = entry.linkedBillId != null;
    final sourceLabel = entry.source == 'bill'
        ? 'Bill'
        : entry.source == 'scan'
            ? 'Scan'
            : 'Manual';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          entry.source == 'bill'
              ? Icons.receipt_long
              : isIn
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
          color: entry.source == 'bill'
              ? Colors.deepPurple
              : isIn
                  ? Colors.green
                  : Colors.orange,
        ),
        title: Text(
          '${isIn ? '+' : '-'}${entry.weight} kg | '
          '${StockUtils.itemLabel(entry.gauge, entry.packing2_5kg)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$date | $sourceLabel'
          '${entry.note.isNotEmpty ? ' | ${entry.note}' : ''}'
          '${isBillLinked ? ' | Linked to bill' : ''}',
        ),
        trailing: isBillLinked
            ? const Icon(Icons.lock_outline, color: Colors.black38)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editEntry(entry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteEntry(entry),
                  ),
                ],
              ),
      ),
    );
  }
}
