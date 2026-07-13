import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorite_provider.dart';
import '../utils/error_messages.dart';

enum FavoriteButtonSize { compact, large }

/// Heart toggle for a listing, backed by [favoriteIdsProvider] so every
/// instance showing the same listing (browse grid, listing detail, my
/// listings, favorites screen) stays in sync. Carries its own [Material]
/// so it works when overlaid on an image inside a [Stack], regardless of
/// the surrounding widget tree.
class FavoriteButton extends ConsumerWidget {
  final String listingId;
  final FavoriteButtonSize size;

  const FavoriteButton({
    super.key,
    required this.listingId,
    this.size = FavoriteButtonSize.compact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(favoriteIdsProvider);
    final isFavorited = idsAsync.valueOrNull?.contains(listingId) ?? false;
    final dimension = size == FavoriteButtonSize.compact ? 32.0 : 44.0;
    final iconSize = size == FavoriteButtonSize.compact ? 18.0 : 22.0;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            try {
              await ref.read(favoriteIdsProvider.notifier).toggle(listingId);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(friendlyErrorMessage(e))),
                );
              }
            }
          },
          child: Icon(
            isFavorited ? Icons.favorite : Icons.favorite_border,
            color: isFavorited ? Colors.redAccent : Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
