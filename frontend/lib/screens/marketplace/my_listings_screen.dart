import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/listing_card.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';

/// The signed-in student's own listings with status control:
/// edit, mark sold/rented/available, delete (with confirmation).
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => MyListingsScreenState();
}

class MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  late Future<List<Listing>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _fetch();
  }

  Future<List<Listing>> _fetch() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return Future.value([]);
    return ref.read(listingServiceProvider).fetchMyListings(user.id);
  }

  void reload() {
    setState(() {
      _listingsFuture = _fetch();
    });
  }

  Future<void> _onRefresh() async {
    final future = _fetch();
    setState(() {
      _listingsFuture = future;
    });
    await future;
  }

  Future<void> _setStatus(Listing listing, String status) async {
    try {
      await ref.read(listingServiceProvider).updateStatus(listing.id!, status);
      reload();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(Listing listing) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateListingScreen(existing: listing)),
    );
    if (changed == true) reload();
  }

  Future<void> _confirmDelete(Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text(
          '"${listing.title}" will be removed permanently, including its photos. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(listingServiceProvider).deleteListing(listing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted')),
        );
      }
      reload();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyErrorMessage(e))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Listing>>(
      future: _listingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                friendlyErrorMessage(snapshot.error!),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final listings = snapshot.data ?? [];
        if (listings.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.sell_outlined, size: 56, color: AppColors.slate),
                SizedBox(height: 12),
                Text(
                  "You haven't listed anything yet.\nTap \"Sell an item\" to get started!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final listing = listings[index];
                  return ListingCard(
                    listing: listing,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: listing),
                      ),
                    ),
                    footer: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statusChip(listing.status),
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: PopupMenuButton<String>(
                            tooltip: 'Listing actions',
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  _edit(listing);
                                case 'delete':
                                  _confirmDelete(listing);
                                default:
                                  _setStatus(listing, action);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              if (listing.status == 'active') ...[
                                PopupMenuItem(
                                  value: listing.listingType == 'rent' ? 'rented' : 'sold',
                                  child: Text(
                                    listing.listingType == 'rent'
                                        ? 'Mark as rented'
                                        : 'Mark as sold',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'unavailable',
                                  child: Text('Mark as unavailable'),
                                ),
                              ] else
                                const PopupMenuItem(
                                  value: 'active',
                                  child: Text('Mark as available'),
                                ),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'active' => ('Active', AppColors.verified),
      'sold' => ('Sold', AppColors.slate),
      'rented' => ('Rented', AppColors.goldDeep),
      _ => ('Unavailable', AppColors.slate),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
