import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/status_chip.dart';
import '../chat/chat_detail_screen.dart';
import '../profile/seller_profile_screen.dart';
import '../transactions/pending_purchase_screen.dart';

/// Full listing view: photo gallery, all details, seller row, and actions
/// (Buy/Book starts a deal → QR handshake; Message Seller opens a chat).
class ListingDetailScreen extends ConsumerStatefulWidget {
  final Listing listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _pageController = PageController();
  int _currentPhoto = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// No deal/transaction is created here — that only happens once payment is
  /// actually confirmed held, in [PendingPurchaseScreen]. Tapping Buy/Book
  /// and backing out without paying now leaves no trace in My Deals.
  void _startDeal() {
    final listing = widget.listing;
    if (listing.status != 'active') return;

    final myId = ref.read(authServiceProvider).currentUser?.id;
    if (myId == listing.sellerId) {
      _comingSoonSnack("That's your own listing.");
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PendingPurchaseScreen(listing: listing)),
    );
  }

  void _comingSoonSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareListing(Listing listing) async {
    final isRent = listing.listingType == 'rent';
    final priceText =
        'RM ${listing.price.toStringAsFixed(2)}${isRent ? ' / day' : ''}';
    await Clipboard.setData(
      ClipboardData(text: '${listing.title} — $priceText\n\nvia UniLink'),
    );
    if (mounted) {
      _comingSoonSnack('Listing details copied — paste it anywhere to share.');
    }
  }

  /// "today" / "N days ago" / "N weeks ago" / "N months ago" — no package
  /// needed for this coarse a granularity.
  String _postedAgo(DateTime? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays <= 0) return 'Posted today';
    if (diff.inDays == 1) return 'Posted yesterday';
    if (diff.inDays < 7) return 'Posted ${diff.inDays} days ago';
    if (diff.inDays < 30) {
      return 'Posted ${(diff.inDays / 7).floor()} weeks ago';
    }
    return 'Posted ${(diff.inDays / 30).floor()} months ago';
  }

  /// One conversation per seller (not per listing, Carousell/Shopee-style):
  /// finds or creates the thread with this seller, sends a "you're asking
  /// about this" product card as a real message (Shopee-style — skipped if
  /// the most recent message already points at the same listing, so
  /// re-opening the same product's chat doesn't spam duplicate cards), then
  /// opens straight into the full existing history.
  Future<void> _messageSeller() async {
    final listing = widget.listing;
    final myId = ref.read(authServiceProvider).currentUser?.id;
    if (myId == listing.sellerId) {
      _comingSoonSnack("That's your own listing.");
      return;
    }

    final chatService = ref.read(chatServiceProvider);
    final conversationId = await chatService.getOrCreateConversation(
      sellerId: listing.sellerId,
      listingId: listing.id,
    );
    await chatService.sendProductCard(conversationId, listing.id!);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: conversationId,
          title: listing.sellerName ?? 'Seller',
          otherUserId: listing.sellerId,
        ),
      ),
    );
  }

  /// Maps a non-active listing status to a display label + [StatusVariant]
  /// for the [StatusChip] shown next to the price.
  (String, StatusVariant) _statusDisplay(String status) {
    return switch (status) {
      'sold' => ('Sold', StatusVariant.warning),
      'rented' => ('Rented', StatusVariant.warning),
      _ => ('Unavailable', StatusVariant.neutral),
    };
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final infoBlue = isDark ? AppColorsDark.infoBlue : AppColors.infoBlue;
    final isRent = listing.listingType == 'rent';
    final isActive = listing.status == 'active';
    final sellerName = listing.sellerName ?? 'Student';

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // --- Photo gallery ---
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child:
                          listing.imageUrls.isEmpty
                              ? ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                              : PageView.builder(
                                controller: _pageController,
                                itemCount: listing.imageUrls.length,
                                onPageChanged:
                                    (index) =>
                                        setState(() => _currentPhoto = index),
                                itemBuilder:
                                    (context, index) => CachedNetworkImage(
                                      imageUrl: listing.imageUrls[index],
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (_, __) => ColoredBox(
                                            color:
                                                scheme.surfaceContainerHighest,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      errorWidget:
                                          (_, __, ___) => ColoredBox(
                                            color:
                                                scheme.surfaceContainerHighest,
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      i == _currentPhoto
                                          ? scheme.secondary
                                          : Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (listing.id != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            FavoriteButton(
                              listingId: listing.id!,
                              size: FavoriteButtonSize.large,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _CircleIconButton(
                              icon: Icons.share_outlined,
                              onTap: () => _shareListing(listing),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Badges ---
                    Row(
                      children: [
                        _badge(
                          context,
                          isRent ? 'FOR RENT' : 'FOR SALE',
                          background: isRent ? infoBlue : scheme.primary,
                          foreground: Colors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusChip(
                          label: listing.condition == 'new' ? 'New' : 'Used',
                          variant:
                              listing.condition == 'new'
                                  ? StatusVariant.success
                                  : StatusVariant.neutral,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _badge(
                          context,
                          listing.category.toUpperCase(),
                          background: scheme.surfaceContainerHighest,
                          foreground: scheme.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      listing.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (listing.location != null &&
                            listing.location!.trim().isNotEmpty)
                          _metaRow(
                            context,
                            Icons.location_on_outlined,
                            listing.location!,
                          ),
                        if (listing.createdAt != null)
                          _metaRow(
                            context,
                            Icons.schedule_outlined,
                            _postedAgo(listing.createdAt),
                          ),
                      ],
                    ),
                    if (listing.tags.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final tag in listing.tags)
                            Text(
                              '#$tag',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'RM ${listing.price.toStringAsFixed(2)}${isRent ? ' / day' : ''}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: scheme.secondary),
                        ),
                        if (!isActive) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Builder(
                            builder: (context) {
                              final (label, variant) = _statusDisplay(
                                listing.status,
                              );
                              return StatusChip(label: label, variant: variant);
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // --- Seller ---
                    Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => SellerProfileScreen(
                                      sellerId: listing.sellerId,
                                    ),
                              ),
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: scheme.primary,
                                child: Text(
                                  sellerName.isNotEmpty
                                      ? sellerName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(color: scheme.onPrimary),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  sellerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'DESCRIPTION',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      listing.description,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // --- Actions ---
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label:
                            isActive
                                ? (isRent ? 'Book' : 'Buy')
                                : _statusDisplay(listing.status).$1,
                        icon: isActive ? Icons.shield_outlined : null,
                        onPressed: isActive ? _startDeal : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        label: 'Message Seller',
                        icon: Icons.chat_bubble_outline,
                        onPressed: _messageSeller,
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

  Widget _badge(
    BuildContext context,
    String text, {
    required Color background,
    required Color foreground,
  }) {
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

  Widget _metaRow(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
