import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/features/wishlists/data/wishlist_repository.dart';

class WishlistState {
  final List<WishlistModel> wishlists;
  final Set<String> savedListingIds;
  final bool isLoading;

  const WishlistState({
    this.wishlists = const [],
    this.savedListingIds = const {},
    this.isLoading = false,
  });

  WishlistState copyWith({
    List<WishlistModel>? wishlists,
    Set<String>? savedListingIds,
    bool? isLoading,
  }) {
    return WishlistState(
      wishlists: wishlists ?? this.wishlists,
      savedListingIds: savedListingIds ?? this.savedListingIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  final WishlistRepository _repository;

  WishlistNotifier(this._repository) : super(const WishlistState());

  Future<void> loadWishlists() async {
    state = state.copyWith(isLoading: true);
    try {
      final wishlists = await _repository.getWishlists();
      // Build savedListingIds from all wishlists
      final allSavedIds = <String>{};
      for (final w in wishlists) {
        for (final l in w.listings) {
          allSavedIds.add(l.id);
        }
      }
      state = state.copyWith(wishlists: wishlists, savedListingIds: allSavedIds, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<WishlistModel> createWishlist(String name) async {
    final wishlist = await _repository.createWishlist(name);
    state = state.copyWith(wishlists: [...state.wishlists, wishlist]);
    return wishlist;
  }

  Future<void> addListing(String wishlistId, String listingId) async {
    await _repository.addListing(wishlistId, listingId);
    state = state.copyWith(
      savedListingIds: {...state.savedListingIds, listingId},
    );
    await loadWishlists();
  }

  Future<void> removeListing(String wishlistId, String listingId) async {
    await _repository.removeListing(wishlistId, listingId);
    final ids = {...state.savedListingIds};
    ids.remove(listingId);
    state = state.copyWith(savedListingIds: ids);
    await loadWishlists();
  }

  bool isListingSaved(String listingId) => state.savedListingIds.contains(listingId);
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>((ref) {
  return WishlistNotifier(WishlistRepository());
});
