import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/explore/presentation/providers/explore_provider.dart';
import 'package:stayspot/features/explore/presentation/screens/search_modal.dart';
import 'package:stayspot/features/explore/presentation/widgets/listing_card.dart';
import 'package:stayspot/features/wishlists/presentation/providers/wishlist_provider.dart';
import 'package:stayspot/features/wishlists/presentation/widgets/save_to_wishlist_sheet.dart';
import 'package:stayspot/shared/widgets/skeleton_loading.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(exploreProvider.notifier).loadInitialListings();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    if (_loadMoreAttempted) return; // Only try once per location
    final state = ref.read(exploreProvider);
    if (state.selectedLocationName == null) return;
    // Only auto-load if we have few listings (likely still generating)
    if (state.listings.length >= 6) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  bool _loadMoreAttempted = false;

  Future<void> _loadMore() async {
    final currentCount = ref.read(exploreProvider).listings.length;
    setState(() {
      _isLoadingMore = true;
      _loadMoreAttempted = true;
    });

    // Poll every 3s for up to 30s, waiting for new listings to appear
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await ref.read(exploreProvider.notifier).refreshCurrentListings();
      final newCount = ref.read(exploreProvider).listings.length;
      if (newCount > currentCount) break;
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _openSearchModal() {
    _loadMoreAttempted = false; // Reset for new search
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.95,
        child: SearchModal(),
      ),
    );
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (context) => const _FilterModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: GestureDetector(
                onTap: _openSearchModal,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.searchBar),
                    boxShadow: AppShadows.searchBar,
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.selectedLocationName ?? 'Where to?',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              state.selectedLocationName != null
                                  ? '${state.listings.length} places found'
                                  : 'Anywhere · Any week · Add guests',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _openFilterModal,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFDDDDDD)),
                          ),
                          child: const Icon(Icons.tune, size: 20, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: state.isGenerating
                  ? _buildGeneratingState(state.generatingLocation)
                  : state.isLoading
                      ? _buildLoadingState()
                      : state.error != null
                          ? _buildErrorState(state.error!)
                          : state.listings.isEmpty
                              ? _buildEmptyState()
                              : _buildListingsList(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingState(String? location) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Discovering places in ${location ?? 'this area'}...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This may take a few seconds',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 3,
      itemBuilder: (_, _) => const ListingCardSkeleton(),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(exploreProvider.notifier).loadInitialListings(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, size: 64, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text(
              'No places found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching for a destination to get started',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsList(ExploreState state) {
    final showBottomLoader = _isLoadingMore && state.selectedLocationName != null;
    final itemCount = state.listings.length + (showBottomLoader ? 1 : 0);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(exploreProvider.notifier).refreshCurrentListings(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= state.listings.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            );
          }
          final listing = state.listings[index];
          final isSaved = ref.watch(wishlistProvider).savedListingIds.contains(listing.id);
          return ListingCard(
            listing: listing,
            isFavorited: isSaved,
            onTap: () {
              context.push('/listing/${listing.id}');
            },
            onFavoriteTap: () {
              final auth = ref.read(authProvider);
              if (auth.status != AuthStatus.authenticated) {
                context.push('/login');
                return;
              }
              if (isSaved) {
                // Find which wishlist has this listing and remove it
                final wishlists = ref.read(wishlistProvider).wishlists;
                for (final w in wishlists) {
                  if (w.listings.any((l) => l.id == listing.id)) {
                    ref.read(wishlistProvider.notifier).removeListing(w.id, listing.id);
                    break;
                  }
                }
              } else {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => SaveToWishlistSheet(listingId: listing.id),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _FilterModal extends ConsumerStatefulWidget {
  const _FilterModal();

  @override
  ConsumerState<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends ConsumerState<_FilterModal> {
  late RangeValues _priceRange;
  String? _propertyType;
  late int _guests;
  final Set<String> _selectedAmenities = {};

  @override
  void initState() {
    super.initState();
    final filters = ref.read(exploreProvider).filters;
    _priceRange = RangeValues(filters.minPrice, filters.maxPrice);
    _propertyType = filters.propertyType;
    _guests = filters.guests;
  }

  static const _amenities = [
    ('wifi', 'Wifi', Icons.wifi),
    ('kitchen', 'Kitchen', Icons.kitchen),
    ('pool', 'Pool', Icons.pool),
    ('parking', 'Parking', Icons.local_parking),
    ('ac', 'AC', Icons.ac_unit),
    ('washer', 'Washer', Icons.local_laundry_service),
    ('gym', 'Gym', Icons.fitness_center),
    ('hot_tub', 'Hot tub', Icons.hot_tub),
    ('tv', 'TV', Icons.tv),
    ('balcony', 'Balcony', Icons.balcony),
    ('workspace', 'Workspace', Icons.desktop_windows),
    ('fireplace', 'Fireplace', Icons.fireplace),
  ];

  void _apply() {
    ref.read(exploreProvider.notifier).applyFilters(
          minPrice: _priceRange.start,
          maxPrice: _priceRange.end,
          propertyType: _propertyType,
          guests: _guests,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _priceRange = const RangeValues(0, 500);
                  _propertyType = null;
                  _guests = 1;
                  _selectedAmenities.clear();
                }),
                child: const Text('Clear all', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price range
                  const Text('Price range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 500,
                    divisions: 50,
                    activeColor: AppColors.primary,
                    labels: RangeLabels(
                      '\$${_priceRange.start.toInt()}',
                      _priceRange.end >= 500 ? '\$500+' : '\$${_priceRange.end.toInt()}',
                    ),
                    onChanged: (v) => setState(() => _priceRange = v),
                  ),
                  Text(
                    '\$${_priceRange.start.toInt()} – ${_priceRange.end >= 500 ? '\$500+' : '\$${_priceRange.end.toInt()}'} / night',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Property type
                  const Text('Property type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _typeChip('ENTIRE_PLACE', 'Entire place'),
                      _typeChip('PRIVATE_ROOM', 'Private room'),
                      _typeChip('SHARED_ROOM', 'Shared room'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Guests
                  const Text('Guests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_guests', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: _guests < 12 ? () => setState(() => _guests++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amenities
                  const Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenities.map((a) {
                      final selected = _selectedAmenities.contains(a.$1);
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a.$3, size: 16, color: selected ? Colors.white : AppColors.textPrimary),
                            const SizedBox(width: 6),
                            Text(a.$2),
                          ],
                        ),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selectedAmenities.add(a.$1);
                          } else {
                            _selectedAmenities.remove(a.$1);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Apply button
          ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Show results'),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _propertyType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
      onSelected: (v) => setState(() => _propertyType = v ? value : null),
    );
  }
}
