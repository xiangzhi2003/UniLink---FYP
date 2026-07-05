import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';

/// Grid card for one listing: photo, sale/rent badge, title, price,
/// condition and seller name. Used by the browse grid and my-listings.
class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;

  /// Extra row content (e.g. my-listings' status chip + actions menu).
  final Widget? footer;

  const ListingCard({super.key, required this.listing, required this.onTap, this.footer});

  @override
  Widget build(BuildContext context) {
    final isRent = listing.listingType == 'rent';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  listing.imageUrls.isEmpty
                      ? const ColoredBox(
                          color: AppColors.line,
                          child: Icon(Icons.image_not_supported_outlined, color: AppColors.slate),
                        )
                      : CachedNetworkImage(
                          imageUrl: listing.imageUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ColoredBox(
                            color: AppColors.line,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: AppColors.line,
                            child: Icon(Icons.broken_image_outlined, color: AppColors.slate),
                          ),
                        ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRent ? AppColors.ink : AppColors.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRent ? 'RENT' : 'SALE',
                        style: TextStyle(
                          color: isRent ? Colors.white : AppColors.inkDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'RM ${listing.price.toStringAsFixed(2)}${isRent ? ' /day' : ''}',
                    style: const TextStyle(
                      color: AppColors.goldDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${listing.condition == 'new' ? 'New' : 'Used'}'
                    '${listing.sellerName != null ? ' · ${listing.sellerName}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.slate, fontSize: 12),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 6),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
