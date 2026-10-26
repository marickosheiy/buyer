import 'package:flutter/services.dart';

/// Lumear contact forms use the local Philippine mobile format: 09XXXXXXXXX.
abstract final class MobileNumber {
  static const maxLength = 11;
  static const error = 'Enter an 11-digit mobile number starting with 09.';
  static final _local = RegExp(r'^09[0-9]{9}$');
  static bool isValid(String value) => _local.hasMatch(value.trim());
  static List<TextInputFormatter> get inputFormatters => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(maxLength),
  ];

  /// Preserve existing international-format contacts when opening an editor.
  /// Unrecognized values remain visible for correction rather than being guessed.
  static String forEditing(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^\+?639[0-9]{9}$').hasMatch(compact)) {
      return '0${compact.replaceFirst(RegExp(r'^\+?63'), '')}';
    }
    return isValid(compact) ? compact : value.trim();
  }
}
