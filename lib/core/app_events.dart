import 'package:flutter/foundation.dart';

class AppEvents {
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  static void notifyDataChanged() => dataVersion.value++;
}