import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/supabase_config.dart';
import '../models/wallet.dart';

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

  Future<Map<String, dynamic>> _get(String path) async {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not signed in');
    }

    final response = await http.get(
      Uri.parse('$backendUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
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

  /// Start payment for a listing directly — no deal exists yet. Returns the
  /// Checkout URL to open plus the session id to reconcile afterwards.
  Future<({String checkoutUrl, String sessionId})> startEscrowCheckout({
    required String listingId,
    required String sellerId,
    required String type,
    int? rentalDays,
  }) async {
    final json = await _post('/escrow/start', {
      'listing_id': listingId,
      'seller_id': sellerId,
      'type': type,
      if (rentalDays != null) 'rental_days': rentalDays,
    });
    return (
      checkoutUrl: json['checkout_url'] as String,
      sessionId: json['session_id'] as String,
    );
  }

  /// Call after returning from Checkout for a deal started via
  /// [startEscrowCheckout] — creates the deal for the first time, but only
  /// once payment is confirmed held. `transactionId` is null while still
  /// waiting on payment.
  Future<({String? transactionId, String escrowStatus})> confirmAndCreateEscrow({
    required String sessionId,
    required String listingId,
    required String sellerId,
    required String type,
  }) async {
    final json = await _post('/escrow/confirm-and-create', {
      'session_id': sessionId,
      'listing_id': listingId,
      'seller_id': sellerId,
      'type': type,
    });
    return (
      transactionId: json['transaction_id'] as String?,
      escrowStatus: json['escrow_status'] as String,
    );
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

  /// Index a listing for semantic search (call after create/update).
  Future<void> embedListing(String listingId) async {
    await _post('/search/embed-listing', {'listing_id': listingId});
  }

  /// Remove a listing's vector (call after delete).
  Future<void> deleteListingVector(String listingId) async {
    await _post('/search/delete-listing', {'listing_id': listingId});
  }

  /// Semantic search — returns listing ids, most relevant first.
  Future<List<String>> searchListings(String query) async {
    final json = await _post('/search/query', {'query': query});
    return (json['listing_ids'] as List<dynamic>).cast<String>();
  }

  /// Simulated wallet balance + earnings history.
  Future<WalletSummary> fetchWalletSummary() async {
    final json = await _get('/wallet/summary');
    return WalletSummary.fromJson(json);
  }
}
