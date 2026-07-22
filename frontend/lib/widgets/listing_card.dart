// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : listing_card.dart
// Description     : Grid card widget showing one listing's photo, badge, title, price and seller.
// First Written on: Sunday,05-Jul-2026
// Edited on       : Monday,13-Jul-2026

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';
import 'favorite_button.dart';
import 'status_chip.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final infoBlue = isDark ? AppColorsDark.infoBlue : AppColors.infoBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
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
                      ? ColoredBox(
                          color: scheme.outline,
                          child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
                        )
                      : CachedNetworkImage(
                          imageUrl: listing.imageUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(
                            color: scheme.outline,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: scheme.outline,
                            child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                          ),
                        ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        // SALE reads as primary violet, RENT as a distinct
                        // blue — matching the reference's badge convention.
                        color: isRent ? infoBlue : scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRent ? 'RENT' : 'SALE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  if (listing.id != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FavoriteButton(listingId: listing.id!),
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
                    style: TextStyle(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusChip(
                        label: listing.condition == 'new' ? 'New' : 'Used',
                        variant: listing.condition == 'new'
                            ? StatusVariant.success
                            : StatusVariant.neutral,
                      ),
                      if (listing.sellerName != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.sellerName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
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
