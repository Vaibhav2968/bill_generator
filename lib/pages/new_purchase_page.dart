import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/purchase.dart';
import '../pages/scan_page.dart';
import '../services/storage_service.dart';
import '../utils/gauge_utils.dart';
import '../utils/scan_parser.dart';
import '../utils/stock_utils.dart';

class NewPurchasePage extends StatefulWidget {
  final double? lastBasePrice;
  final Purchase? purchaseToEdit;

  const NewPurchasePage({
    super.key,
    this.lastBasePrice,
    this.purchaseToEdit,
  });

  bool get isEditing => purchaseToEdit != null;

  @override
  State<NewPurchasePage> createState() => _NewPurchasePageState();
}

class _PurchaseLineDraft {
  final double gauge;
  final double weight;
  final bool packing2_5kg;

  const _PurchaseLineDraft({
    required this.gauge,
    required this.weight,
    this.packing2_5kg = false,
  });

  PurchaseLine toLine() => PurchaseLine(
        gauge: gauge,
        weight: weight,
        packing2_5kg: packing2_5kg,
      );
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  final _storage = StorageService();
  final _basePriceController = TextEditingController();
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();

  final List<_PurchaseLineDraft> _lines = [];
  double? _selectedGauge;
  bool _selectedPacking2_5kg = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.purchaseToEdit;
    if (editing != null) {
      _basePriceController.text = editing.basePrice.round().toString();
      _noteController.text = editing.note;
      _lines.addAll(
        editing.lines.map(
          (line) => _PurchaseLineDraft(
            gauge: line.gauge,
            weight: line.weight,
            packing2_5kg: line.packing2_5kg,
          ),
        ),
      );
    } else if (widget.lastBasePrice != null && widget.lastBasePrice! > 0) {
      _basePriceController.text = widget.lastBasePrice!.round().toString();
    }
  }

  @override
  void dispose() {
    _basePriceController.dispose();
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _basePrice => double.tryParse(_basePriceController.text.trim());

  double get _runningTotal {
    final base = _basePrice;
    if (base == null) return 0;
    return _lines.fold<double>(
      0,
      (sum, line) =>
          sum +
          PurchaseLine(
            gauge: line.gauge,
            weight: line.weight,
            packing2_5kg: line.packing2_5kg,
          ).amountAtBase(base),
    );
  }

  void _addLine({
    required double gauge,
    required double weight,
    bool packing2_5kg = false,
  }) {
    final base = _basePrice;
    if (base == null || base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter purchase base price first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final normalized = GaugeUtils.normalizeGauge(gauge);
    if (normalized == null) return;

    setState(() {
      _lines.add(
        _PurchaseLineDraft(
          gauge: normalized,
          weight: weight,
          packing2_5kg: packing2_5kg,
        ),
      );
      _selectedGauge = null;
      _selectedPacking2_5kg = false;
      _weightController.clear();
    });
  }

  void _addManualLine() {
    final weight = double.tryParse(_weightController.text.trim());
    if (_selectedGauge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a gauge')),
      );
      return;
    }
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid weight')),
      );
      return;
    }
    _addLine(
      gauge: _selectedGauge!,
      weight: weight,
      packing2_5kg: _selectedPacking2_5kg,
    );
  }

  Future<void> _openScanner() async {
    final data = await Navigator.push<ScanProductData>(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );
    if (!mounted || data == null) return;

    final gauge = GaugeUtils.normalizeGauge(data.size);
    if (gauge == null) return;

    _addLine(
      gauge: gauge,
      weight: data.netWeight,
      packing2_5kg: data.packing2_5kg,
    );
  }

  Future<void> _savePurchase() async {
    final base = _basePrice;
    if (base == null || base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter purchase base price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }

    try {
      if (widget.isEditing) {
        final existing = widget.purchaseToEdit!;
        final purchase = Purchase(
          id: existing.id,
          date: existing.date,
          basePrice: base,
          lines: _lines.map((line) => line.toLine()).toList(),
          note: _noteController.text.trim(),
        );
        await _storage.updatePurchase(purchase);
      } else {
        final purchase = Purchase(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now(),
          basePrice: base,
          lines: _lines.map((line) => line.toLine()).toList(),
          note: _noteController.text.trim(),
        );
        await _storage.savePurchase(purchase);
      }
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final base = _basePrice;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Purchase' : 'New Purchase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _basePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Purchase base price (Rs.)',
                hintText: 'e.g. 1390 — rate for this buy only',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            const Text(
              'Each purchase can have its own base price. Older stock keeps its original rate.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add items to this purchase',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<double>(
              value: _selectedGauge,
              decoration: const InputDecoration(
                labelText: 'Gauge',
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
            const SizedBox(height: 8),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addManualLine,
                    child: const Text('Add item'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_lines.isNotEmpty) ...[
              Text(
                'Purchase items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...List.generate(_lines.length, (index) {
                final line = _lines[index];
                final lineAmount = base == null
                    ? 0.0
                    : line.toLine().amountAtBase(base);
                final unit = base == null
                    ? 0.0
                    : line.toLine().unitPriceAtBase(base);
                return Card(
                  child: ListTile(
                    title: Text(StockUtils.itemLabel(
                      line.gauge,
                      line.packing2_5kg,
                    )),
                    subtitle: Text(
                      '${line.weight} kg × Rs. ${unit.round()}/kg',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rs. ${lineAmount.round()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() => _lines.removeAt(index));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total purchase amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${_runningTotal.round()}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _savePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  widget.isEditing
                      ? 'Update purchase & stock'
                      : 'Save purchase & add to stock',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
