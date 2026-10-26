import 'dart:convert';

import 'package:flutter/services.dart';

/// Postal codes are postal routing data, not a suffix of a PSGC code.
/// Use the bundled PHLPost snapshot instead of guessing from geographic IDs.
class PostalCodeService {
  PostalCodeService._(this.entries);
  final List<dynamic> entries;
  static PostalCodeService? _instance;

  static Future<PostalCodeService> load() async {
    if (_instance != null) return _instance!;
    final text = await rootBundle.loadString(
      'assets/data/ph_postal_codes.json',
    );
    final data = jsonDecode(text.replaceFirst('\uFEFF', ''));
    return _instance = PostalCodeService._(data['entries'] as List);
  }

  static String _normalize(String text) {
    var value = text.toLowerCase().trim();
    // Accommodate accented names and the current API's mojibake spellings.
    value = value.replaceAll('ã±', 'n').replaceAll('ñ', 'n');
    for (final entry in {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
    }.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    value = value.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    value = value.replaceAll(RegExp(r'\bcity of\b|\bcity\b'), ' ');
    value = value.replaceAll(RegExp(r'\bsta\.?\s+'), 'santa ');
    value = value.replaceAll(RegExp(r'\bsto\.?\s+'), 'santo ');
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String? find({required String province, required String municipality}) {
    final provinceKey = _normalize(province);
    final cityKey = _normalize(municipality);
    if (provinceKey.isEmpty || cityKey.isEmpty) return null;
    final codes = <String>{};
    for (final row in entries) {
      if (_normalize(row['province'] as String) == provinceKey &&
          _normalize(row['locality'] as String) == cityKey) {
        final code = row['postal_code'] as String;
        if (RegExp(r'^\d{4}$').hasMatch(code)) codes.add(code);
      }
    }
    // Never choose arbitrarily between multiple routing codes.
    return codes.length == 1 ? codes.single : null;
  }
}
