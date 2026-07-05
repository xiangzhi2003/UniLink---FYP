import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/listing.dart';
import '../../theme/app_theme.dart';

/// Full listing view: photo gallery, all details, seller row, and
/// placeholder actions (messaging and escrow arrive in Sprint 3).
class ListingDetailScreen extends StatefulWidget {
  final Listing listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _pageController = PageController();
  int _currentPhoto = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming in Sprint 3 — stay tuned!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final isRent = listing.listingType == 'rent';
    final sellerName = listing.sellerName ?? 'Student';

    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // --- Photo gallery ---
              AspectRatio(
                aspectRatio: 4 / 3,
                child: listing.imageUrls.isEmpty
                    ? const ColoredBox(
                        color: AppColors.line,
                        child: Icon(Icons.image_not_supported_outlined,
                            size: 48, color: AppColors.slate),
                      )
                    : Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: listing.imageUrls.length,
                            onPageChanged: (index) =>
                                setState(() => _currentPhoto = index),
                            itemBuilder: (context, index) => CachedNetworkImage(
                              imageUrl: listing.imageUrls[index],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ColoredBox(
                                color: AppColors.line,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: AppColors.line,
                                child: Icon(Icons.broken_image_outlined,
                                    color: AppColors.slate),
                              ),
                            ),
                          ),
                          if (listing.imageUrls.length > 1)
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < listing.imageUrls.length; i++)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i == _currentPhoto
                                            ? AppColors.gold
                                            : Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Badges ---
                    Row(
                      children: [
                        _badge(
                          isRent ? 'FOR RENT' : 'FOR SALE',
                          background: isRent ? AppColors.ink : AppColors.gold,
                          foreground: isRent ? Colors.white : AppColors.inkDeep,
                        ),
                        const SizedBox(width: 8),
                        _badge(
                          listing.condition == 'new' ? 'NEW' : 'USED',
                          background: AppColors.line,
                          foreground: AppColors.ink,
                        ),
                        const SizedBox(width: 8),
                        _badge(
                          listing.category.toUpperCase(),
                          background: AppColors.line,
                          foreground: AppColors.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      'RM ${listing.price.toStringAsFixed(2)}${isRent ? ' / day' : ''}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.goldDeep,
                          ),
                    ),
                    const SizedBox(height: 18),
                    // --- Seller ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.ink,
                            child: Text(
                              sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sellerName,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const Text(
                                  'Verified student',
                                  style: TextStyle(color: AppColors.verified, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('DESCRIPTION', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(
                      listing.description,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    // --- Actions (placeholders until Sprint 3) ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _comingSoon(isRent ? 'Booking with escrow' : 'Buying with escrow'),
                        icon: const Icon(Icons.shield_outlined, size: 18),
                        label: Text(isRent ? 'Book' : 'Buy'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _comingSoon('In-app messaging'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.ink),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message Seller'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, {required Color background, required Color foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
