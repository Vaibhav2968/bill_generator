import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';

import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

import 'models/customer.dart';
import 'models/bill_stock_line.dart';
import 'models/ledger_entry.dart';
import 'models/saved_bill.dart';
import 'pages/bill_page.dart';
import 'pages/customers_page.dart';
import 'pages/profit_loss_page.dart';
import 'pages/scan_page.dart';
import 'pages/stock_page.dart';
import 'services/storage_service.dart';
import 'utils/gauge_utils.dart';
import 'utils/scan_parser.dart';
import 'utils/whatsapp_utils.dart';
import 'widgets/bill_number_dialog.dart';
import 'widgets/customer_picker_dialog.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gauge Price Calculator',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController baseAmountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.deepPurple.shade200,
        title: const Text(
          'Gauge Price Calculator',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/purple.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                child: TextField(
                  controller: baseAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Base amount',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  String input = baseAmountController.text.trim();
                  if (input.isEmpty) {
                    // Show an error message if the user did not enter any value.
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Error'),
                          content: const Text('Please enter a valid amount.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  } else if (double.tryParse(input) == null) {
                    // Show an error message if the entered value is not a valid integer.
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Error'),
                          content: const Text('Please enter a valid integer.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    // Navigate to the ResultPage if the entered value is valid.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultPage(
                          baseAmount: double.parse(input),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Calculate',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomersPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white70,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Customers & Ledger',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StockPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white70,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Manage Stock',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfitLossPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white70,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Profit & Loss',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryPage(),
                    ),
                  );
                },
                child: const Text(
                  'View Bill History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BillLineItem {
  final double gauge;
  final double weight;
  final double amount;
  final bool packing2_5kg;

  const BillLineItem({
    required this.gauge,
    required this.weight,
    required this.amount,
    this.packing2_5kg = false,
  });
}

class ResultPage extends StatefulWidget {
  final double baseAmount;

  const ResultPage({Key? key, required this.baseAmount}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final List<BillLineItem> lineItems = [];

  double? selectedGauge;
  double multiplier = 1.0;
  bool selectedPacking2_5kg = false;

  TextEditingController multiplierController = TextEditingController();
  final StorageService _storage = StorageService();

  final ScrollController _listViewController = ScrollController();
  final ScrollController _columnViewController = ScrollController();
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _columnViewController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_columnViewController.offset >=
            _columnViewController.position.maxScrollExtent &&
        !_columnViewController.position.outOfRange) {
      setState(() {
        _showButton = true;
      });
    } else {
      setState(() {
        _showButton = false;
      });
    }
  }

  void _addLineItem(
    double gauge,
    double weight, {
    bool packing2_5kg = false,
  }) {
    final normalized = GaugeUtils.normalizeGauge(gauge) ?? gauge;
    final calculatedAmount = GaugeUtils.calculateAmount(
      widget.baseAmount,
      normalized,
      weight,
      packing2_5kg: packing2_5kg,
    );
    setState(() {
      lineItems.add(
        BillLineItem(
          gauge: normalized,
          weight: weight,
          amount: calculatedAmount,
          packing2_5kg: packing2_5kg,
        ),
      );
    });
  }

  void _addFromManualEntry() {
    if (selectedGauge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a gauge',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (multiplier == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid weight',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _addLineItem(
      selectedGauge!,
      multiplier,
      packing2_5kg: selectedPacking2_5kg,
    );
    setState(() {
      selectedGauge = null;
      multiplier = 1.0;
      selectedPacking2_5kg = false;
      multiplierController.text = '';
    });
  }

  void _addFromScan(ScanProductData data) {
    final gauge = GaugeUtils.normalizeGauge(data.size);
    if (gauge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid SWG size: ${data.size}. Check gauge list.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _addLineItem(
      gauge,
      data.netWeight,
      packing2_5kg: data.packing2_5kg,
    );
  }

  void _removeLineItem(int index) {
    setState(() {
      lineItems.removeAt(index);
    });
  }

  Future<void> _confirmRemoveLineItem(int index) async {
    final item = lineItems[index];
    final gaugeLabel = GaugeUtils.formatGaugeLabel(item.gauge);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text(
          'Gauge $gaugeLabel | ${item.weight} kg'
          '${item.packing2_5kg ? ' | 2.5kg pack' : ''} | '
          'Rs. ${item.amount.round()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _removeLineItem(index);
    }
  }

  Future<void> _editLineItem(int index) async {
    final item = lineItems[index];
    double? editGauge = item.gauge;
    bool editPacking = item.packing2_5kg;
    final weightController =
        TextEditingController(text: item.weight.toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('2.5 kg packing (+Rs. 5/kg)'),
                        value: editPacking,
                        onChanged: (value) {
                          setDialogState(() {
                            editPacking = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                    const SizedBox(height: 16),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter valid gauge and weight'),
                          backgroundColor: Colors.red,
                        ),
                      );
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
        final amount = GaugeUtils.calculateAmount(
          widget.baseAmount,
          editGauge!,
          weight,
          packing2_5kg: editPacking,
        );
        setState(() {
          lineItems[index] = BillLineItem(
            gauge: editGauge!,
            weight: weight,
            amount: amount,
            packing2_5kg: editPacking,
          );
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      weightController.dispose();
    });
  }

  List<BillStockLine> _toStockLines() {
    return lineItems
        .map(
          (item) => BillStockLine(
            gauge: item.gauge,
            weight: item.weight,
            packing2_5kg: item.packing2_5kg,
          ),
        )
        .toList();
  }

  Future<bool> _confirmStockShortages(
    BuildContext context,
    List<String> shortages,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low stock'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Not enough stock for:'),
              const SizedBox(height: 12),
              ...shortages.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $line'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Generate bill anyway? Stock will still be reduced.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _openScanner() async {
    final data = await Navigator.push<ScanProductData>(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );
    if (!mounted || data == null) return;

    _addFromScan(data);
    final packingNote =
        data.packing2_5kg ? ' | 2.5kg pack' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added SWG ${GaugeUtils.formatGaugeLabel(data.size)} | '
          '${data.netWeight} kg$packingNote',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _columnViewController.removeListener(_scrollListener);
    _columnViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Visibility(
        visible: _showButton,
        child: FloatingActionButton(
          onPressed: () {
            _columnViewController.animateTo(0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut);
          },
          child: const Icon(Icons.arrow_upward),
        ),
      ),
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: SingleChildScrollView(
        controller: _listViewController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add some space above the Text widget
              const SizedBox(height: 20),

// Decorate the Text widget with a fancy font and bold style
              const Text(
                'Select a gauge:',
                style: TextStyle(
                  fontFamily: 'Pacific',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 10),
              DropdownButton<double>(
                value: selectedGauge,
                isExpanded: true,
                onChanged: (double? value) {
                  setState(() {
                    selectedGauge = value;
                    if (value == null ||
                        !GaugeUtils.supportsPacking2_5kg(value)) {
                      selectedPacking2_5kg = false;
                    }
                  });
                },
                items: GaugeUtils.gaugeDropdownItems(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                hint: const Text(
                  'Select a gauge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                underline: Container(
                  height: 2,
                  color: Colors.black,
                ),
              ),
              if (selectedGauge != null &&
                  GaugeUtils.supportsPacking2_5kg(selectedGauge!))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '2.5 kg packing (+Rs. 5/kg)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('For gauge 20, 21, 22, 23, 24, 25, 26'),
                  value: selectedPacking2_5kg,
                  onChanged: (value) {
                    setState(() {
                      selectedPacking2_5kg = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const SizedBox(height: 20),
              TextField(
                controller: multiplierController,
                decoration: InputDecoration(
                  labelText: 'Enter a weight',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Colors.blueGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  hintText: 'e.g. 10.0 kg',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.height),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      multiplierController.clear();
                      setState(() {
                        multiplier = 0;
                      });
                    },
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  fillColor: Colors.white,
                  filled: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (String value) {
                  setState(() {
                    multiplier = double.tryParse(value) ?? 0;
                  });
                },
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addFromManualEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Calculate',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openScanner,
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                      label: const Text(
                        'Scan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Calculated amounts:',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              ListView.builder(
                controller: _columnViewController,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lineItems.length,
                itemBuilder: (context, index) {
                  final item = lineItems[index];
                  final gaugeprice = GaugeUtils.unitPrice(
                    widget.baseAmount,
                    item.gauge,
                    packing2_5kg: item.packing2_5kg,
                  );
                  final gaugeText =
                      GaugeUtils.formatGaugeLabel(item.gauge);
                  final packingText = item.packing2_5kg ? ' | 2.5kg pack' : '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(
                          gaugeText,
                          style: TextStyle(
                            color: Colors.deepPurple.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        'Gauge $gaugeText swg$packingText',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Price: ₹${gaugeprice.round()} | '
                        'Weight: ${item.weight} kg | '
                        'Amount: Rs. ${item.amount.round()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            color: Colors.deepPurple,
                            tooltip: 'Edit',
                            onPressed: () => _editLineItem(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            tooltip: 'Remove',
                            onPressed: () => _confirmRemoveLineItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ElevatedButton(
                  onPressed: () {
                    if (lineItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Add at least one item before showing bill'),
                        ),
                      );
                      return;
                    }

                    final pageContext = context;
                    final totalAmount = lineItems
                        .fold<double>(0, (sum, item) => sum + item.amount)
                        .roundToDouble();
                    final totalWeight = lineItems.fold<double>(
                      0,
                      (sum, item) => sum + item.weight,
                    );
                    String billDetails = '';

                    // ignore: non_constant_identifier_names
                    String Total = '';
                    // ignore: non_constant_identifier_names
                    String Price = '';
                    // ignore: non_constant_identifier_names
                    String Gauge = '';
                    // ignore: non_constant_identifier_names
                    String Weight = '';
                    // ignore: non_constant_identifier_names
                    String Amount = '';
                    // ignore: non_constant_identifier_names
                    String BillDetails = '';

                    for (final item in lineItems) {
                      final gaugeprice = GaugeUtils.unitPrice(
                        widget.baseAmount,
                        item.gauge,
                        packing2_5kg: item.packing2_5kg,
                      );
                      final gaugeText =
                          GaugeUtils.formatGaugeLabel(item.gauge);
                      final packingText =
                          item.packing2_5kg ? ' (2.5kg pack)' : '';

                      billDetails +=
                          'Gauge:$gaugeText$packingText , Price:$gaugeprice, Weight:${item.weight} kg,  Amount:${item.amount.round()}\n\n';
                      BillDetails +=
                          'Gauge:$gaugeText$packingText\nPrice:$gaugeprice\nWeight:${item.weight} kg\nAmount:${item.amount.round()}\n\n';
                      Price += 'Rs.$gaugeprice\n';
                      Gauge += '$gaugeText swg$packingText\n';
                      Weight += '${item.weight} kg\n';
                      Amount += 'Rs.${item.amount.round()}\n';
                    }
                    billDetails +=
                        '\nTOTAL WEIGHT: ${totalWeight} kg\nTOTAL:    ${totalAmount.round()}';
                    BillDetails +=
                        '\nTOTAL WEIGHT: ${totalWeight} kg\nTOTAL:    ${totalAmount.round()}';
                    Total +=
                        '\nTOTAL WEIGHT: ${totalWeight} kg\nTOTAL: Rs. ${totalAmount.round()}';

                    showDialog(
                      context: pageContext,
                      builder: (dialogContext) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          physics: const BouncingScrollPhysics(),
                          child: AlertDialog(
                            title: const Text(
                              'Bill Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  billDetails,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  final customer =
                                      await showDialog<Customer>(
                                    context: pageContext,
                                    builder: (context) =>
                                        const CustomerPickerDialog(),
                                  );
                                  if (customer == null) return;
                                  if (!pageContext.mounted) return;

                                  final billDate = DateTime.now();
                                  final suggested =
                                      await _storage.peekNextBillNumber(
                                    billDate,
                                  );
                                  if (!pageContext.mounted) return;

                                  final billNumber = await showBillNumberDialog(
                                    pageContext,
                                    suggested: suggested,
                                    date: billDate,
                                  );
                                  if (billNumber == null) return;
                                  if (!pageContext.mounted) return;

                                  final stockLines = _toStockLines();
                                  final shortages =
                                      await _storage.checkStockShortages(
                                    stockLines,
                                  );
                                  if (!pageContext.mounted) return;
                                  if (shortages.isNotEmpty) {
                                    final proceed = await _confirmStockShortages(
                                      pageContext,
                                      shortages,
                                    );
                                    if (!proceed || !pageContext.mounted) return;
                                  }

                                  await _storage.reserveBillNumber(billNumber);

                                  final ledgerId =
                                      DateTime.now().millisecondsSinceEpoch
                                          .toString();

                                  final billString =
                                      'Bill No: $billNumber\nDate:\n${DateFormat.yMMMd().format(billDate)}\nCustomer Name:${customer.name} \n\n$billDetails';

                                  await _storage.addBillToHistory(billString);
                                  await _storage.addLedgerEntry(
                                    LedgerEntry(
                                      id: ledgerId,
                                      customerId: customer.id,
                                      date: billDate,
                                      type: 'bill',
                                      amount: totalAmount,
                                      note: billNumber,
                                    ),
                                  );
                                  await _storage.deductStockForBill(
                                    linkedBillId: ledgerId,
                                    billNumber: billNumber,
                                    lines: stockLines,
                                  );
                                  await _storage.saveSavedBill(
                                    SavedBill(
                                      ledgerEntryId: ledgerId,
                                      customerId: customer.id,
                                      date: billDate,
                                      billNumber: billNumber,
                                      billDetails: billDetails,
                                      billDetailsFormatted: BillDetails,
                                      total: Total,
                                      price: Price,
                                      weight: Weight,
                                      amount: Amount,
                                      gauge: Gauge,
                                      totalAmount: totalAmount,
                                      totalWeight: totalWeight,
                                      lineItems: stockLines,
                                    ),
                                  );

                                  if (!pageContext.mounted) return;
                                  ScaffoldMessenger.of(pageContext).showSnackBar(
                                    const SnackBar(
                                      content: Text('Stock updated for this bill'),
                                    ),
                                  );
                                  Navigator.push(
                                    pageContext,
                                    MaterialPageRoute(
                                      builder: (context) => BillPage(
                                        billDetails: billDetails,
                                        total: Total,
                                        price: Price,
                                        customer: customer,
                                        weight: Weight,
                                        amount: Amount,
                                        gauge: Gauge,
                                        billDetailsFormatted: BillDetails,
                                        totalAmount: totalAmount,
                                        totalWeight: totalWeight,
                                        billNumber: billNumber,
                                        ledgerEntryId: ledgerId,
                                        billDate: billDate,
                                      ),
                                    ),
                                  );
                                },
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.deepPurple,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 20),
                                    child: Text(
                                      'Generate Bill',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 30),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Show Bill',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final priceList = GaugeUtils.buildPriceListText(
                      widget.baseAmount,
                      DateTime.now(),
                    );
                    final customer = await showDialog<Customer>(
                      context: context,
                      builder: (context) => const CustomerPickerDialog(),
                    );
                    if (!context.mounted) return;
                    if (customer != null) {
                      final opened = await WhatsAppUtils.shareText(
                        phone: customer.whatsappNumber,
                        message: priceList,
                      );
                      if (!opened && context.mounted) {
                        await Share.share(priceList);
                      }
                    } else {
                      await Share.share(priceList);
                    }
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Share Price List (Today)'),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Base amount: Rs. ${widget.baseAmount.round()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Display a header for Gauges 13-26
              const Text(
                'Gauges 13-26:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 10), // Add a bit of vertical space

              ListView.builder(
                controller: _columnViewController,
                shrinkWrap: true,
                itemCount: GaugeUtils.gauges13to26.length,
                itemBuilder: (context, index) {
                  final gauge = GaugeUtils.gauges13to26[index];
                  final price =
                      GaugeUtils.unitPrice(widget.baseAmount, gauge).round();
                  return Card(
                    elevation: 2, // Add a slight shadow to the card
                    margin: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16), // Add some margin
                    child: ListTile(
                      title: Text(
                        'Gauge ${GaugeUtils.formatGaugeLabel(gauge)}: Rs. $price',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight
                                .bold), // Make the title bold and increase font size
                      ),
                      trailing: const Icon(Icons
                          .arrow_forward_ios), // Add an arrow icon to the right of the list tile
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              const Text(
                'Gauges 27-36:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                controller: _columnViewController,
                shrinkWrap: true,
                itemCount: GaugeUtils.gauges27to36.length,
                itemBuilder: (context, index) {
                  final gauge = GaugeUtils.gauges27to36[index];
                  final price =
                      GaugeUtils.unitPrice(widget.baseAmount, gauge).round();
                  return Card(
                    elevation: 2, // Add a slight shadow to the card
                    margin: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16), // Add some margin
                    child: ListTile(
                      title: Text(
                        'Gauge ${GaugeUtils.formatGaugeLabel(gauge)}: Rs. $price',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight
                                .bold), // Make the title bold and increase font size
                      ),
                      trailing: const Icon(Icons
                          .arrow_forward_ios), // Add an arrow icon to the right of the list tile
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _storage = StorageService();
  List<String> history = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final loaded = await _storage.getBillHistory();
    if (!mounted) return;
    setState(() {
      history = loaded;
    });
  }

  List<String> getFilteredHistory() {
    if (searchQuery.isEmpty) {
      return history.reversed.toList();
    }
    final query = searchQuery.toLowerCase();
    return history
        .where((billString) => billString.toLowerCase().contains(query))
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or date',
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
          ),
          Expanded(
            child: getFilteredHistory().isEmpty
                ? const Center(
                    child: Text('No bills found'),
                  )
                :  ListView.builder(
              itemCount: getFilteredHistory().length,
              itemBuilder: (context, index) {
                String billString = getFilteredHistory()[index];
                return Dismissible(
                  key: Key(billString),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    int historyIndex = history.length - 1 - index; // get index in original list
                    String billString = history[historyIndex];

                    // remove the bill from the history
                    List<String> newHistory = await _storage.getBillHistory();
                    newHistory.removeAt(historyIndex);
                    await _storage.saveBillHistory(newHistory);

                    // reload the history
                    setState(() {
                      history = newHistory;
                    });

                    // remove the dismissed item from the widget tree
                    setState(() {
                      getFilteredHistory().removeAt(index);
                    });

                    // show a snackbar to confirm the deletion
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Bill deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            // add the bill back to the history
                            List<String> restored = await _storage.getBillHistory();
                            restored.insert(historyIndex, billString);
                            await _storage.saveBillHistory(restored);

                            // reload the history
                            setState(() {
                              this.history = restored;
                            });
                          },
                        ),
                      ),
                    );
                  },



                  child: Card(
                          margin: const EdgeInsets.all(8),
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          shadowColor: Colors.grey.shade200,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 50, right: 50, bottom: 20, top: 20),
                            child: Text(
                              billString,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                                letterSpacing: 0.5,
                                wordSpacing: 1.0,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
