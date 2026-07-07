import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_chip.dart';
import '../chat/chat_detail_screen.dart';
import '../transactions/transaction_detail_screen.dart';

/// Full listing view: photo gallery, all details, seller row, and actions
/// (Buy/Book starts a deal → QR handshake; Message Seller opens a chat).
class ListingDetailScreen extends ConsumerStatefulWidget {
  final Listing listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _pageController = PageController();
  int _currentPhoto = 0;
  bool _booking = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _startDeal() async {
    final listing = widget.listing;
    if (listing.status != 'active') return;

    final myId = ref.read(authServiceProvider).currentUser?.id;

    if (myId == listing.sellerId) {
      _comingSoonSnack("That's your own listing.");
      return;
    }

    setState(() => _booking = true);
    try {
      final dealId = await ref.read(transactionServiceProvider).createTransaction(
            listingId: listing.id!,
            sellerId: listing.sellerId,
            type: listing.listingType,
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(dealId: dealId)),
      );
    } catch (e) {
      if (mounted) _comingSoonSnack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _comingSoonSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _messageSeller() async {
    final listing = widget.listing;
    final myId = ref.read(authServiceProvider).currentUser?.id;
    if (myId == listing.sellerId) {
      _comingSoonSnack("That's your own listing.");
      return;
    }

    try {
      final convoId = await ref.read(chatServiceProvider).getOrCreateConversation(
            listingId: listing.id!,
            sellerId: listing.sellerId,
          );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversationId: convoId,
            title: listing.sellerName ?? 'Seller',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _comingSoonSnack(friendlyErrorMessage(e));
    }
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
                child: listing.imageUrls.isEmpty
                    ? ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported_outlined,
                            size: 48, color: scheme.onSurfaceVariant),
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
                              placeholder: (_, __) => ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(Icons.broken_image_outlined,
                                    color: scheme.onSurfaceVariant),
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
                                            ? scheme.secondary
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
                          variant: listing.condition == 'new'
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
                    Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'RM ${listing.price.toStringAsFixed(2)}${isRent ? ' / day' : ''}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: scheme.secondary,
                              ),
                        ),
                        if (!isActive) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Builder(builder: (context) {
                            final (label, variant) = _statusDisplay(listing.status);
                            return StatusChip(label: label, variant: variant);
                          }),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // --- Seller ---
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primary,
                            child: Text(
                              sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?',
                              style: TextStyle(color: scheme.onPrimary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(sellerName,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('DESCRIPTION', style: Theme.of(context).textTheme.labelLarge),
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
                        label: isActive ? (isRent ? 'Book' : 'Buy') : _statusDisplay(listing.status).$1,
                        icon: isActive ? Icons.shield_outlined : null,
                        isLoading: _booking,
                        onPressed: isActive && !_booking ? _startDeal : null,
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

  Widget _badge(BuildContext context, String text,
      {required Color background, required Color foreground}) {
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
