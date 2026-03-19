// mobile_config.dart

// Mobile responsive configuration and constants

class MobileConfig {
  // Grid size constants
  static const double gridSize = 8.0;

  // UI dimensions
  static const double widthBreakpoint = 600.0;
  static const double heightBreakpoint = 800.0;

  // Touch optimization
  static const double touchTargetSize = 48.0; // in pixels

  // Utility function to check if the device is mobile
  static bool isMobile(double width) {
    return width < widthBreakpoint;
  }
}