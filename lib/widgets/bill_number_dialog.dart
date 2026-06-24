import 'package:flutter/material.dart';

import '../utils/bill_number_utils.dart';

Future<String?> showBillNumberDialog(
  BuildContext context, {
  required String suggested,
  required DateTime date,
}) async {
  final controller = TextEditingController(text: suggested);
  final fyLabel = BillNumberUtils.financialYearLabel(date);

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bill Number'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial year: $fyLabel (Apr - Mar)',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Bill number',
              hintText: 'e.g. 1-2627',
              border: OutlineInputBorder(),
              helperText: 'Format: number-FY (example 5-2627)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = BillNumberUtils.normalize(
              controller.text,
              date,
            );
            if (value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  return result;
}
