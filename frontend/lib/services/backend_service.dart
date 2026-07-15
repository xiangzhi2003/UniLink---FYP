import 'dart:convert';
import 'dart:typed_data';

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

  /// Pay for a listing straight from the wallet balance — no Stripe redirect,
  /// the deal is created already held. Throws if the balance is insufficient.
  Future<String> payWithWallet({
    required String listingId,
    required String sellerId,
    required String type,
    int? rentalDays,
  }) async {
    final json = await _post('/escrow/pay-with-wallet', {
      'listing_id': listingId,
      'seller_id': sellerId,
      'type': type,
      if (rentalDays != null) 'rental_days': rentalDays,
    });
    return json['transaction_id'] as String;
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

  /// Conversational AI search — a short bounded history of prior turns lets
  /// the reply stay coherent across follow-up messages (e.g. "actually I
  /// need one with graphing").
  Future<({String reply, List<String> listingIds})> askConcierge({
    required String message,
    required List<({String role, String text})> history,
  }) async {
    final json = await _post('/search/concierge', {
      'message': message,
      'history': [
        for (final turn in history) {'role': turn.role, 'text': turn.text},
      ],
    });
    return (
      reply: json['reply'] as String,
      listingIds: (json['listing_ids'] as List<dynamic>).cast<String>(),
    );
  }

  /// AI chatbot scoped to one specific listing — answers questions about
  /// that item using both its real details and the model's own general
  /// knowledge, and can point to similar listings.
  Future<({String reply, List<String> relatedListingIds})> askAboutListing({
    required String listingId,
    required String message,
    required List<({String role, String text})> history,
  }) async {
    final json = await _post('/search/listing-chat', {
      'listing_id': listingId,
      'message': message,
      'history': [
        for (final turn in history) {'role': turn.role, 'text': turn.text},
      ],
    });
    return (
      reply: json['reply'] as String,
      relatedListingIds: (json['related_listing_ids'] as List<dynamic>).cast<String>(),
    );
  }

  /// AI-assisted listing creation: suggest a title/description/category/
  /// price from a seller's rough note and/or up to 3 photos.
  Future<({String title, String description, String category, double? price})>
      suggestListingDetails({String? note, List<Uint8List>? images}) async {
    final json = await _post('/search/suggest-listing', {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'images_base64': [for (final img in images ?? []) base64Encode(img)],
    });
    return (
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num?)?.toDouble(),
    );
  }

  /// Simulated wallet balance + earnings history.
  Future<WalletSummary> fetchWalletSummary() async {
    final json = await _get('/wallet/summary');
    return WalletSummary.fromJson(json);
  }

  /// Start a real Stripe Checkout session for a withdrawal (setup mode — no
  /// real charge, but a genuine stripe.com page, same rhythm as deposit).
  Future<({String checkoutUrl, String sessionId})> startWalletWithdrawal(double amount) async {
    final json = await _post('/wallet/withdraw/start', {'amount': amount});
    return (
      checkoutUrl: json['checkout_url'] as String,
      sessionId: json['session_id'] as String,
    );
  }

  /// Call after returning from Checkout to apply the withdrawal. `credited`
  /// is false if the session was never completed or the balance is no
  /// longer sufficient.
  Future<({bool credited, WalletSummary summary})> confirmWalletWithdrawal(String sessionId) async {
    final json = await _post('/wallet/withdraw/confirm', {'session_id': sessionId});
    return (
      credited: json['credited'] as bool,
      summary: WalletSummary.fromJson({'balance': json['balance'], 'history': json['history']}),
    );
  }

  /// Start a Stripe Checkout session to top up the wallet.
  Future<({String checkoutUrl, String sessionId})> startWalletDeposit(double amount) async {
    final json = await _post('/wallet/deposit/start', {'amount': amount});
    return (
      checkoutUrl: json['checkout_url'] as String,
      sessionId: json['session_id'] as String,
    );
  }

  /// Call after returning from Checkout to credit the deposit. `credited` is
  /// false if the payment was never actually completed (e.g. backed out of
  /// Checkout) — the balance/history are returned either way for display.
  Future<({bool credited, WalletSummary summary})> confirmWalletDeposit(String sessionId) async {
    final json = await _post('/wallet/deposit/confirm', {'session_id': sessionId});
    return (
      credited: json['credited'] as bool,
      summary: WalletSummary.fromJson({'balance': json['balance'], 'history': json['history']}),
    );
  }
}
