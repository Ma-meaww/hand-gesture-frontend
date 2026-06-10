import 'package:flutter/foundation.dart';

import '../models/gesture_mapping.dart';

class GestureSettingsService {
  final ValueNotifier<GestureMapping> mapping =
      ValueNotifier(GestureMapping());

  void update(GestureMapping newMapping) {
    mapping.value = newMapping;
  }

  void reset() {
    mapping.value = GestureMapping();
  }
}

final gestureSettingsService = GestureSettingsService();