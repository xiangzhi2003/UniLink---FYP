import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/supabase_config.dart';

/// Thin authed client for our FastAPI backend. Every call carries the current
/// Supabase access token as a Bearer header so the backend can verify who's
/// calling and that they're a party to the transaction.
class BackendService {
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not signed in');
    }

    final response = await http.post(
      Uri.parse('$backendUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final decoded = response.body.isEmpty ? {} : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Request failed (${response.statusCode})';
      throw Exception(detail);
    }
    return (decoded as Map).cast<String, dynamic>();
  }

  /// The QR payload the current giver should display, plus seconds to refresh.
  Future<({String payload, int expiresIn})> fetchCurrentQr(String transactionId) async {
    final json = await _post('/qr/current', {'transaction_id': transactionId});
    return (payload: json['payload'] as String, expiresIn: json['expires_in'] as int);
  }

  /// Submit a scanned/typed code. Returns the new status + a message.
  Future<({String status, String phase, String message})> verifyQr(
    String transactionId,
    String code,
  ) async {
    final json = await _post('/qr/verify', {
      'transaction_id': transactionId,
      'code': code,
    });
    return (
      status: json['status'] as String,
      phase: json['phase'] as String,
      message: json['message'] as String,
    );
  }

  /// Start escrow payment — returns the Stripe Checkout URL to open.
  Future<String> createEscrowCheckout(String transactionId) async {
    final json = await _post('/escrow/create', {'transaction_id': transactionId});
    return json['checkout_url'] as String;
  }

  /// Sync whether the payment is now held (call after returning from Checkout).
  Future<String> confirmEscrow(String transactionId) async {
    final json = await _post('/escrow/confirm', {'transaction_id': transactionId});
    return json['escrow_status'] as String;
  }

  /// Cancel the deal and release the hold (before pickup only).
  Future<String> refundEscrow(String transactionId) async {
    final json = await _post('/escrow/refund', {'transaction_id': transactionId});
    return json['escrow_status'] as String;
  }
}
