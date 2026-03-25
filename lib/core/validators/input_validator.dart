/// Input validation utilities to prevent injection and invalid data
class InputValidator {
  /// Validates map key format
  static bool isValidMapKey(String? key) {
    if (key == null || key.isEmpty) return false;
    // Only allow alphanumeric and specific characters
    final validPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!validPattern.hasMatch(key)) return false;
    // Limit length to prevent abuse
    if (key.length > 50) return false;
    return true;
  }

  /// Validates grid coordinates
  static bool isValidCoordinate(int? value, int max) {
    if (value == null) return false;
    return value >= 0 && value < max;
  }

  /// Validates grid position
  static bool isValidPosition(int col, int row, int maxCols, int maxRows) {
    return isValidCoordinate(col, maxCols) && isValidCoordinate(row, maxRows);
  }

  /// Validates numeric range
  static bool isInRange(num value, num min, num max) {
    return value >= min && value <= max;
  }

  /// Sanitizes string input
  static String sanitizeString(String input, {int maxLength = 100}) {
    // Remove control characters and limit length
    final sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    return sanitized.length > maxLength
        ? sanitized.substring(0, maxLength)
        : sanitized;
  }
}
