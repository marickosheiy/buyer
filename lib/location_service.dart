import 'dart:convert';

import 'package:http/http.dart' as http;

class LocationService {
  static const String baseUrl = 'https://psgc.cloud/api/v2';

  // ============================================================
  // GET REGIONS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getRegions() async {
    final response = await http.get(Uri.parse('$baseUrl/regions'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    throw Exception('Failed to load regions');
  }

  // ============================================================
  // GET PROVINCES BY REGION
  // ============================================================

  static Future<List<Map<String, dynamic>>> getProvinces(
    String regionCode,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/regions/$regionCode/provinces'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    throw Exception('Failed to load provinces');
  }

  // ============================================================
  // GET CITIES / MUNICIPALITIES BY PROVINCE
  // ============================================================

  static Future<List<Map<String, dynamic>>> getCitiesMunicipalities(
    String provinceCode,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/provinces/$provinceCode/cities-municipalities'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    throw Exception('Failed to load cities and municipalities');
  }

  // ============================================================
  // GET BARANGAYS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getBarangays(
    String cityMunicipalityCode,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/cities-municipalities/'
        '$cityMunicipalityCode/barangays',
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    throw Exception('Failed to load barangays');
  }
}
