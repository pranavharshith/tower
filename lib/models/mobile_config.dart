// mobile_config.dart

import 'package:flutter/material.dart';

// Mobile configuration constants
const String apiUrl = 'https://api.example.com';
const String appVersion = '1.0.0';

// Responsive scaling logic
class Responsive {
  static double scale(double value, {double baseWidth = 375.0}) {
    final mediaQueryData = WidgetsBinding.instance.window;
    return value * (mediaQueryData.physicalSize.width / baseWidth);
  }

  static double height(double value, {double baseHeight = 667.0}) {
    final mediaQueryData = WidgetsBinding.instance.window;
    return value * (mediaQueryData.physicalSize.height / baseHeight);
  }
}
