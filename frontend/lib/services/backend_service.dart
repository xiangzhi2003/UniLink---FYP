import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class BackendService {
  Future<bool> checkEmailExists(String email) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/check-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['exists'] as bool;
  }
}
