import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GaugeUtils {
  static const packing2_5kgExtra = 5.0;

  static const gauges13to26 = <double>[
    13, 13.5, 14, 14.5, 15, 15.5, 16, 16.5, 17, 17.5, 18, 18.5, 19, 19.5,
    20, 20.5, 21, 21.5, 22, 22.5, 23, 24, 25, 26,
  ];

  static const gauges27to36 = <double>[
    27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
  ];

  static final Map<double, double> _halfGaugeOffsets = {
    13.5: 0,
    14.5: 0,
    15.5: 0,
    16.5: 0,
    17.5: 0,
    18.5: 0,
    19.5: 0,
    20.5: 0.5,
    21.5: 1.5,
    22.5: 2.5,
  };

  static List<double> get allGauges => [...gauges13to26, ...gauges27to36];

  @Deprecated('Use gauges13to26')
  static List<int> get gauges13to26Names =>
      gauges13to26.where((g) => g % 1 == 0).map((g) => g.round()).toList();

  static double? normalizeGauge(double value) {
    for (final gauge in allGauges) {
      if ((gauge - value).abs() < 0.01) {
        return gauge;
      }
    }
    return null;
  }

  static bool isValidGauge(double gaugeValue) =>
      normalizeGauge(gaugeValue) != null;

  static bool supportsPacking2_5kg(double gaugeValue) {
    final gauge = normalizeGauge(gaugeValue);
    if (gauge == null) return false;
    return gauge >= 20 && gauge <= 26 && gauge % 1 == 0;
  }

  static bool isLikely2_5KgWeight(double weight) =>
      (weight - 2.5).abs() < 0.05;

  static double getPriceOffset(
    double gaugeValue, {
    bool packing2_5kg = false,
  }) {
    final gauge = normalizeGauge(gaugeValue) ?? gaugeValue;
    double offset;

    final halfOffset = _halfOffset(gauge);
    if (halfOffset != null) {
      offset = halfOffset;
    } else if (gauge >= 13 && gauge <= 20) {
      offset = 0;
    } else if (gauge >= 21 && gauge <= 26) {
      offset = gauge - 20;
    } else if (gauge >= 27 && gauge <= 36) {
      offset = gauge;
    } else {
      offset = 0;
    }

    if (packing2_5kg && supportsPacking2_5kg(gauge)) {
      offset += packing2_5kgExtra;
    }

    return offset;
  }

  static double? _halfOffset(double gauge) {
    for (final entry in _halfGaugeOffsets.entries) {
      if ((entry.key - gauge).abs() < 0.01) {
        return entry.value;
      }
    }
    return null;
  }

  static double unitPrice(
    double baseAmount,
    double gaugeValue, {
    bool packing2_5kg = false,
  }) =>
      baseAmount + getPriceOffset(gaugeValue, packing2_5kg: packing2_5kg);

  static double calculateAmount(
    double baseAmount,
    double gaugeValue,
    double weight, {
    bool packing2_5kg = false,
  }) =>
      (unitPrice(baseAmount, gaugeValue, packing2_5kg: packing2_5kg) * weight)
          .roundToDouble();

  static String formatGaugeLabel(double gaugeValue) {
    final gauge = normalizeGauge(gaugeValue) ?? gaugeValue;
    if (gauge % 1 == 0) {
      return gauge.round().toString();
    }
    return gauge.toStringAsFixed(1);
  }

  static String packingLabel(bool packing2_5kg) =>
      packing2_5kg ? '2.5kg pack' : '';

  static List<DropdownMenuItem<double>> gaugeDropdownItems() {
    return allGauges
        .map(
          (gauge) => DropdownMenuItem(
            value: gauge,
            child: Text('Gauge ${formatGaugeLabel(gauge)}'),
          ),
        )
        .toList();
  }

  static String buildPriceListText(double baseAmount, DateTime date) {
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final buffer = StringBuffer()
      ..writeln('WIRE PRICE LIST')
      ..writeln('Date: $dateStr')
      ..writeln('Valid for: $dateStr only')
      ..writeln('Base price: Rs. ${baseAmount.round()}')
      ..writeln('')
      ..writeln('Gauges 13-26 (incl. half sizes):');

    for (final gauge in gauges13to26) {
      final price = unitPrice(baseAmount, gauge).round();
      buffer.writeln('Gauge ${formatGaugeLabel(gauge)}: Rs. $price');
    }

    buffer
      ..writeln('')
      ..writeln('Gauges 27-36:');
    for (final gauge in gauges27to36) {
      final price = unitPrice(baseAmount, gauge).round();
      buffer.writeln('Gauge ${formatGaugeLabel(gauge)}: Rs. $price');
    }

    buffer
      ..writeln('')
      ..writeln(
        '2.5kg packing (Gauge 20-26 only): +Rs. ${packing2_5kgExtra.round()} per kg',
      );

    return buffer.toString().trim();
  }
}
