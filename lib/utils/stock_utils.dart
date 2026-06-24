import '../utils/gauge_utils.dart';

class StockUtils {
  static String itemKey(double gauge, bool packing2_5kg) =>
      '${GaugeUtils.formatGaugeLabel(gauge)}_${packing2_5kg ? 'pack25' : 'std'}';

  static String itemLabel(double gauge, bool packing2_5kg) {
    final gaugeLabel = GaugeUtils.formatGaugeLabel(gauge);
    if (packing2_5kg) {
      return 'Gauge $gaugeLabel swg (2.5kg pack)';
    }
    return 'Gauge $gaugeLabel swg';
  }
}
