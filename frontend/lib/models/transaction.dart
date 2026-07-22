// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : transaction.dart
// Description     : Data model for a TransactionDeal -- a buy/rent transaction including escrow status and rental due dates.
// First Written on: Monday,06-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

class TransactionDeal {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String type; // sale | rent
  final String status; // pending | active | completed | cancelled
  final DateTime? pickupScannedAt;
  final DateTime? returnScannedAt;
  final String escrowStatus; // pending | held | captured | refunded (Sprint 3B)
  final String? checkoutSessionId; // set once the buyer starts Stripe Checkout
  final DateTime createdAt;
  final double? amount; // RM actually charged, snapshotted at confirm-and-create
  final int? rentalDays;
  final DateTime? rentalStartDate;
  final DateTime? rentalDueDate;

  // Joined display fields (not columns on transactions):
  final String? listingTitle;
  final double? listingPrice;
  final List<String> listingImages;
  final String? buyerName;
  final String? sellerName;

  const TransactionDeal({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.type,
    required this.status,
    this.pickupScannedAt,
    this.returnScannedAt,
    required this.escrowStatus,
    this.checkoutSessionId,
    required this.createdAt,
    this.listingTitle,
    this.listingPrice,
    this.listingImages = const [],
    this.buyerName,
    this.sellerName,
    this.amount,
    this.rentalDays,
    this.rentalStartDate,
    this.rentalDueDate,
  });

  /// Which leg of the handshake is next: 'pickup' until the item changes
  /// hands, then 'return' for rentals.
  String get phase => pickupScannedAt == null ? 'pickup' : 'return';

  factory TransactionDeal.fromJson(Map<String, dynamic> json) {
    final listing = json['listings'] as Map<String, dynamic>?;
    final buyer = json['buyer'] as Map<String, dynamic>?;
    final seller = json['seller'] as Map<String, dynamic>?;
    return TransactionDeal(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      pickupScannedAt: json['pickup_scanned_at'] == null
          ? null
          : DateTime.parse(json['pickup_scanned_at'] as String),
      returnScannedAt: json['return_scanned_at'] == null
          ? null
          : DateTime.parse(json['return_scanned_at'] as String),
      escrowStatus: json['escrow_status'] as String? ?? 'pending',
      checkoutSessionId: json['stripe_checkout_session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      listingTitle: listing?['title'] as String?,
      listingPrice: listing?['price'] == null ? null : (listing!['price'] as num).toDouble(),
      listingImages: listing == null
          ? const []
          : (listing['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
      buyerName: buyer?['full_name'] as String?,
      sellerName: seller?['full_name'] as String?,
      amount: json['amount'] == null ? null : (json['amount'] as num).toDouble(),
      rentalDays: json['rental_days'] as int?,
      rentalStartDate: json['rental_start_date'] == null
          ? null
          : DateTime.parse(json['rental_start_date'] as String),
      rentalDueDate: json['rental_due_date'] == null
          ? null
          : DateTime.parse(json['rental_due_date'] as String),
    );
  }
}
