// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : listing.dart
// Description     : Data model for a marketplace Listing (sale or rent item) including price, category, condition, photos and owner.
// First Written on: Sunday,05-Jul-2026
// Edited on       : Monday,13-Jul-2026

class Listing {
  final String? id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String category;
  final String condition;
  final String listingType;
  final String status;
  final List<String> imageUrls;
  final DateTime? createdAt;

  /// Populated when fetched with a `profiles(full_name)` join; not a column
  /// on the listings table itself.
  final String? sellerName;

  final List<String> tags;
  final String? location;

  static const categories = ['Textbooks', 'Electronics', 'Equipment', 'Others'];

  const Listing({
    this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    required this.listingType,
    this.status = 'active',
    required this.imageUrls,
    this.createdAt,
    this.sellerName,
    this.tags = const [],
    this.location,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      condition: json['condition'] as String,
      listingType: json['listing_type'] as String,
      status: json['status'] as String,
      imageUrls: (json['image_urls'] as List<dynamic>).cast<String>(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      sellerName: (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      location: json['location'] as String?,
    );
  }

  /// For inserts — omits id/created_at so Postgres fills in the defaults.
  Map<String, dynamic> toInsertJson() {
    return {
      'seller_id': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'condition': condition,
      'listing_type': listingType,
      'status': status,
      'image_urls': imageUrls,
      'tags': tags,
      'location': location,
    };
  }

  /// For edits — only the fields the edit form can change.
  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'condition': condition,
      'listing_type': listingType,
      'image_urls': imageUrls,
      'tags': tags,
      'location': location,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
