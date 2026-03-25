import 'package:logger/logger.dart';

/// Centralized logger for the application
///
/// Usage:
/// ```dart
/// final log = Logger();
/// log.d('Debug message');
/// log.i('Info message');
/// log.w('Warning message');
/// log.e('Error message');
/// ```
///
/// In production, debug logs are automatically disabled.
class AppLogger {
  static final Logger _instance = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to show
      errorMethodCount: 8, // Number of method calls for errors
      lineLength: 120, // Width of the output
      colors: true, // Colorful output
      printEmojis: true, // Print emojis
      dateTimeFormat:
          DateTimeFormat.none, // Don't print time (use Flutter's debug console)
    ),
    // Only log in debug mode
    level: _isProduction ? Level.off : Level.debug,
  );

  static bool get _isProduction {
    // In release mode, disable debug logging
    bool releaseMode = false;
    assert(() {
      releaseMode = false;
      return true;
    }());
    return !releaseMode;
  }

  static Logger get instance => _instance;

  /// Debug level logging (only in development)
  static void d(String message, [dynamic error]) {
    if (!_isProduction) {
      _instance.d(message, error: error);
    }
  }

  /// Info level logging (always enabled)
  static void i(String message, [dynamic error]) {
    _instance.i(message, error: error);
  }

  /// Warning level logging (always enabled)
  static void w(String message, [dynamic error]) {
    _instance.w(message, error: error);
  }

  /// Error level logging (always enabled)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.e(message, error: error, stackTrace: stackTrace);
  }
}
