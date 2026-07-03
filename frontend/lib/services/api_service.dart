import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/health'));

    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
