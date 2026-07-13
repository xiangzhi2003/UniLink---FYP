import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/favorite_service.dart';
import 'auth_provider.dart';

final favoriteServiceProvider = Provider<FavoriteService>((ref) => FavoriteService());

/// The signed-in user's favorited listing ids, kept in sync across every
/// screen that shows a [FavoriteButton] (browse grid, my listings,
/// favorites screen, listing detail) so toggling one updates them all.
/// Rebuilt (and re-fetched) whenever the signed-in user changes.
final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsNotifier, AsyncValue<Set<String>>>((ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.session?.user.id;
  return FavoriteIdsNotifier(ref, userId);
});

class FavoriteIdsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  final Ref _ref;
  final String? _userId;

  FavoriteIdsNotifier(this._ref, this._userId) : super(const AsyncValue.loading()) {
    if (_userId == null) {
      state = const AsyncValue.data({});
    } else {
      _load(_userId);
    }
  }

  Future<void> _load(String userId) async {
    try {
      final ids = await _ref.read(favoriteServiceProvider).fetchFavoriteListingIds(userId);
      if (mounted) state = AsyncValue.data(ids);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Optimistically flips [listingId]'s favorited state, then confirms
  /// against Supabase — reverts on failure.
  Future<void> toggle(String listingId) async {
    final userId = _userId;
    final current = state.valueOrNull;
    if (userId == null || current == null) return;

    final isFavorited = current.contains(listingId);
    final optimistic = Set<String>.from(current);
    isFavorited ? optimistic.remove(listingId) : optimistic.add(listingId);
    state = AsyncValue.data(optimistic);

    try {
      final service = _ref.read(favoriteServiceProvider);
      if (isFavorited) {
        await service.removeFavorite(userId, listingId);
      } else {
        await service.addFavorite(userId, listingId);
      }
    } catch (e) {
      if (mounted) state = AsyncValue.data(current);
      rethrow;
    }
  }
}
