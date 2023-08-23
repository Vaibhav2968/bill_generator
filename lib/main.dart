import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';


import 'package:flutter_share/flutter_share.dart';

import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';









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
              const SizedBox(height: 20),
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

class ResultPage extends StatefulWidget {
  final double baseAmount;

  const ResultPage({Key? key, required this.baseAmount}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  List<double> gauges21to26 = [16,17,18,19,20,21, 22, 23, 24, 25, 26];
  List<double> gauges21to26price = [0.016,0.017,0.018,0.019,0.020,1, 2, 3, 4, 5, 6];
  Map<double, double> gaugeToAmountMap = {};

  List<double> gauges27to36 = [27, 28, 29, 30, 31, 32, 33, 34, 35, 36];
  List<double> multipliers = [];
  final gauges21to26Names = [16,17,18,19,20,21, 22, 23, 24, 25, 26];

  double? selectedGauge;
  double multiplier = 1.0;
  double totalMultiplier = 1.0;

  List<double> calculatedAmounts = [];

  TextEditingController multiplierController = TextEditingController();
  TextEditingController customerNameController = TextEditingController();

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
                onChanged: (double? value) {
                  setState(() {
                    selectedGauge = value;
                  });
                },
                items: [
                  ...List.generate(
                    gauges21to26price.length,
                    (index) => DropdownMenuItem(
                      value: gauges21to26price[index],
                      child: Text(
                        'Gauge ${gauges21to26Names[index]}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  ...gauges27to36.map(
                    (gauge) => DropdownMenuItem(
                      value: gauge,
                      child: Text(
                        'Gauge $gauge',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
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
              ElevatedButton(
                onPressed: () {
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
                  } else if (multiplier == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a valid weight',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    double calculatedAmount =
                        (widget.baseAmount + (selectedGauge ?? 0)) * multiplier;
                    setState(() {
                      if (gaugeToAmountMap.containsKey(selectedGauge)) {
                        // Update amount for existing gauge
                        int index = gaugeToAmountMap.keys
                            .toList()
                            .indexOf(selectedGauge!);
                        calculatedAmounts[index] = calculatedAmount;
                        multipliers[index] = multiplier;
                        gaugeToAmountMap[selectedGauge!] = calculatedAmount;
                      } else {
                        // Add new gauge to map
                        calculatedAmounts.add(calculatedAmount);
                        multipliers.add(multiplier);
                        gaugeToAmountMap[selectedGauge!] = calculatedAmount;
                      }
                      selectedGauge = null;
                      multiplier = 1.0;
                      multiplierController.text = '';
                      totalMultiplier *= multipliers[multipliers.length - 1];
                    });
                  }
                },
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
                itemCount: calculatedAmounts.length,
                itemBuilder: (context, index) {
                  double gauge = gaugeToAmountMap.keys.elementAt(index);
                  double price = widget.baseAmount;
                  double gaugeprice= gauge + price;
                  double amount = gaugeToAmountMap[gauge]!;
                  double multiplier = multipliers[index];
                  String gaugeText = gauge >= 1 && gauge <= 6
                      ? 'Gauge: ${gauge + 20}'
                      : 'Gauge: $gauge';
                  return ListTile(
                    title: Text(
                      '$gaugeText,Price: (₹$gaugeprice), Weight: $multiplier kg, Amount: Rs. $amount',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        // Example of color customization
                        fontWeight: FontWeight.bold,
                        // Example of font customization
                        fontSize: 16.0, // Example of font size customization
                      ),
                    ),
                    leading: const Icon(
                      Icons.ac_unit,
                      // Example of leading icon customization
                      color: Colors
                          .green, // Example of leading icon color customization
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      // Example of trailing icon customization
                      color: Colors
                          .green, // Example of trailing icon color customization
                    ),
                    onTap: () {
                      // Example of tap action customization
                    },
                  );
                },
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ElevatedButton(
                  onPressed: () {
                    double totalAmount =
                        calculatedAmounts.reduce((a, b) => a + b);
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
                    String BillDetails='';

                    // Iterate over the calculated amounts and create the bill details string
                    for (int i = 0; i < calculatedAmounts.length; i++) {
                      double gauge = gaugeToAmountMap.keys.elementAt(i);
                      double price = widget.baseAmount;
                      double gaugeprice= gauge + price;
                      double amount = gaugeToAmountMap[gauge]!;
                      double multiplier = multipliers[i];
                      String gaugeText = gauge >= 0.1 && gauge <= 6
                          ? '${gauge + 20}'
                          : ' $gauge';

                      billDetails +=
                          'Gauge:$gaugeText , Price:$gaugeprice, Weight:$multiplier kg,  Amount:$amount\n\n';
                      BillDetails +=
                      'Gauge:$gaugeText\nPrice:$gaugeprice\nWeight:$multiplier kg\nAmount:$amount\n\n';
                      Price += 'Rs.$gaugeprice\n';
                      Gauge += '$gaugeText swg\n';
                      Weight +='$multiplier kg\n';
                      Amount +='Rs.$amount\n';



                    }
                    billDetails+='\nTOTAL:    $totalAmount';
                    BillDetails+='\nTOTAL:    $totalAmount';

                    // Add the total amount to the bill details string
                    Total += '\nTOTAL: Rs. $totalAmount';

                    showDialog(
                      context: context,
                      builder: (context) {
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
                                TextField(
                                  controller: customerNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  billDetails,
                                  style: const TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () async {
                                  String customerName =
                                      customerNameController.text;
                                  Navigator.pop(context);

                                  // Create the bill string with the current date and customer name
                                  String billString =
                                      'Date:\n${DateFormat.yMMMd().format(DateTime.now())}\nCustomer Name:$customerName \n\n$billDetails';

                                  // Save the bill to the history
                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();
                                  List<String> history =
                                      prefs.getStringList('billHistory') ?? [];
                                  history.add(billString);
                                  await prefs.setStringList(
                                      'billHistory', history);

                                  // Navigate to the bill page and pass the bill details and customer name
                                  // ignore: use_build_context_synchronously
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BillPage(
                                        billDetails: billDetails,
                                        Total:Total,
                                        Price:Price,
                                        customerName: customerName,
                                        Weight: Weight,
                                        Amount: Amount,
                                        Gauge: Gauge,
                                        BillDetails:BillDetails,
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Base amount: Rs. ${widget.baseAmount}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Display a header for Gauges 21-26
              const Text(
                'Gauges 21-26:',
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
                itemCount: gauges21to26.length,
                itemBuilder: (context, index) {
                  double gauge = gauges21to26[index];
                  double gaugeprice = gauges21to26price[index];
                  double price = widget.baseAmount + gaugeprice;
                  return Card(
                    elevation: 2, // Add a slight shadow to the card
                    margin: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16), // Add some margin
                    child: ListTile(
                      title: Text(
                        'Gauge $gauge: Rs. $price',
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
                itemCount: gauges27to36.length,
                itemBuilder: (context, index) {
                  double gauge = gauges27to36[index];
                  double price = widget.baseAmount + gauge;
                  return Card(
                    elevation: 2, // Add a slight shadow to the card
                    margin: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16), // Add some margin
                    child: ListTile(
                      title: Text(
                        'Gauge $gauge: Rs. $price',
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

class BillPage extends StatefulWidget {
  final String billDetails;
  final String customerName;
  // ignore: non_constant_identifier_names
  final String Total;
  // ignore: non_constant_identifier_names
  final String Price;
  // ignore: non_constant_identifier_names
  final String Weight;
  // ignore: non_constant_identifier_names
  final String Amount;
  // ignore: non_constant_identifier_names
  final String Gauge;
  // ignore: non_constant_identifier_names
  final String BillDetails;


  const BillPage(
      // ignore: non_constant_identifier_names
      {super.key, required this.billDetails, required this.customerName, required this.Total, required this.Price, required this.Weight, required this.Amount, required this.Gauge, required this.BillDetails});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  bool isButtonPressed = false;
  GlobalKey globalKey = GlobalKey();


  Future<void> shareContentAsImage(BuildContext context) async {
    try {
      RenderRepaintBoundary boundary =
      globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/image.png';
      await File(filePath).writeAsBytes(pngBytes);

      await FlutterShare.shareFile(
        title: 'Share via',
        text: 'Image',
        filePath: filePath,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }





  @override
  Widget build(BuildContext context) {
    String date = DateFormat.yMMMd()
        .format(DateTime.now()); // format current date as a string
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bill'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            RepaintBoundary(
              key: globalKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 20.0,
                    ),
                    Text(
                      'Date:', // display the date
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800], // set the text color to blue-grey
                        letterSpacing: 1.0, // add letter spacing
                      ),
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                    Text(
                      date, // display the current date formatted as a string
                      style: TextStyle(
                        fontSize: 18.0,
                        color: Colors.blueGrey[
                            600], // set the text color to a lighter shade of blue-grey
                      ),
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    Text(
                      'Customer Name:',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                    Text(
                      widget.customerName,
                      style: TextStyle(
                        fontSize: 18.0,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    Divider(
                      thickness: 2.0,
                      color: Colors.blueGrey[
                          400], // set the divider color to a lighter shade of blue-grey
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Bill Details:',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Gauge',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  widget.Gauge,
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    color: Colors.blueGrey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const VerticalDivider(
                            color: Colors.blueGrey, // Adjust the color of the vertical line as needed
                            thickness: 1.0, // Adjust the thickness of the vertical line as needed
                          ),
                          Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Price',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  widget.Price,
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    color: Colors.blueGrey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const VerticalDivider(
                            color: Colors.blueGrey, // Adjust the color of the vertical line as needed
                            thickness: 1.0, // Adjust the thickness of the vertical line as needed
                          ),
                          Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Weight',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  widget.Weight,
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    color: Colors.blueGrey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const VerticalDivider(
                            color: Colors.blueGrey, // Adjust the color of the vertical line as needed
                            thickness: 1.0, // Adjust the thickness of the vertical line as needed
                          ),
                          Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  widget.Amount,
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    color: Colors.blueGrey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 10.0,
                    ),
                    SingleChildScrollView(scrollDirection: Axis.horizontal,
                      child: Text(
                        widget.Total,
                        style: const TextStyle(
                          fontSize: 20.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    Divider(
                      thickness: 2.0,
                      color: Colors.blueGrey[400],
                    ),
                    const SizedBox(
                      height: 30.0,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await shareContentAsImage(context);
                      // Additional code for WhatsApp sharing...
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(Colors.deepPurple), // Set the background color
                      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.all(15.0)), // Set the padding
                      shape: MaterialStateProperty.all<OutlinedBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0), // Set the border radius
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.image_outlined,
                          color: Colors.white, // Set the icon color
                        ),
                        SizedBox(width: 8.0), // Add spacing between the icon and text
                        Text(
                          'Share as image',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Set the text color
                          ),
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                    setState(() {
                      isButtonPressed = !isButtonPressed;
                    });
                    String phoneNumber = ''; // replace with the recipient's phone number
                    String message =
                        'Date: ${DateFormat.yMMMd().format(DateTime.now())}\n\n'
                        'Customer Name: ${widget.customerName}\n\n'
                        '${widget.BillDetails}\n\n'
                    // 'Gauge: ${widget.Gauge}    Price: ${widget.Price}     Weight: ${widget.Weight}     Amount: ${widget.Amount}\n\n'
                    // '${widget.Total}\n'
                        'Thank you';

                    await shareContentAsImage(context); // Share the image

                    String whatsappUrl =
                        'https://wa.me/$phoneNumber?text=${Uri.encodeQueryComponent(message)}';

                    // ignore: deprecated_member_use
                    if (await canLaunch(whatsappUrl)) {
                      // ignore: deprecated_member_use, body_might_complete_normally_catch_error
                      await launch(whatsappUrl).catchError((e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                          ),
                        );
                      });
                      // save the bill details to history after sharing via WhatsApp
                    } else {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to open WhatsApp'),
                        ),
                      );
                    }
                  },


                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(Colors.grey), // Set the background color
                      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.all(15.0)), // Set the padding
                      shape: MaterialStateProperty.all<OutlinedBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0), // Set the border radius
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.text_fields_sharp,
                          color: Colors.white, // Set the icon color
                        ),
                        SizedBox(width: 8.0), // Add spacing between the icon and text
                        Text(
                          'Share as text',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Set the text color
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),




            Padding(
              padding: const EdgeInsets.all(50.0),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4B0082), Color(0xFF8B008B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.8),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset:
                        const Offset(0, 3), // changes position of shadow
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (BuildContext context) =>
                              HomePage(key: UniqueKey()),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                    ),
                    child: const Text(
                      'Return to Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),


          ],
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
  List<String> history = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      history = prefs.getStringList('billHistory') ?? [];
    });
  }

  List<String> getFilteredHistory() {
    if (searchQuery.isEmpty) {
      return history.reversed.toList();
    } else {
      return history
          .where((billString) =>
      billString.contains(searchQuery) ||
          DateFormat('MMM d, yyyy')
              .parse(billString.split('\n')[0].split(': ')[1])
              .toString()
              .contains(searchQuery))
          .toList()
          .reversed
          .toList();
    }
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
                // setState(() {
                //   searchQuery = query;
                // });
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
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    List<String> newHistory = prefs.getStringList('billHistory') ?? [];
                    newHistory.removeAt(historyIndex);
                    await prefs.setStringList('billHistory', newHistory);

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
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            List<String> history = prefs.getStringList('billHistory') ?? [];
                            history.insert(historyIndex, billString);
                            await prefs.setStringList('billHistory', history);

                            // reload the history
                            setState(() {
                              this.history = history;
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
