import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/core/constants.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/listing_detail/presentation/providers/listing_detail_provider.dart';
import 'package:stayspot/features/wishlists/presentation/providers/wishlist_provider.dart';
import 'package:stayspot/features/wishlists/presentation/widgets/save_to_wishlist_sheet.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class ListingDetailScreen extends ConsumerWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listingDetailProvider(listingId));

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (state.error != null || state.listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(state.error ?? 'Listing not found')),
      );
    }

    final listing = state.listing!;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Image gallery
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: _circleButton(context, Icons.arrow_back, () => context.pop()),
                actions: [
                  GestureDetector(
                    onTap: () {
                      final auth = ref.read(authProvider);
                      if (auth.status != AuthStatus.authenticated) {
                        context.push('/login');
                        return;
                      }
                      final isSaved = ref.read(wishlistProvider).savedListingIds.contains(listing.id);
                      if (isSaved) {
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
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                      ),
                      child: Icon(
                        ref.watch(wishlistProvider).savedListingIds.contains(listing.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                        color: ref.watch(wishlistProvider).savedListingIds.contains(listing.id)
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: listing.images.isNotEmpty
                      ? PageView.builder(
                          itemCount: listing.images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = '${ApiConstants.imageBaseUrl}${listing.images[index].url}';
                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.surface,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textTertiary),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.surface,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported, size: 64, color: AppColors.textTertiary),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.home, size: 64, color: AppColors.textTertiary),
                          ),
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Title
                    Text(listing.title, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    // Stats row
                    Text(
                      listing.statsText,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: AppColors.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          '${listing.averageRating.toStringAsFixed(1)} · ${listing.reviewCount} reviews',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (listing.location != null) ...[
                          const Text(' · ', style: TextStyle(color: AppColors.textSecondary)),
                          Flexible(
                            child: Text(
                              listing.location!.name ?? '',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 32),

                    // Host card
                    _buildHostCard(context, listing),
                    const Divider(height: 32),

                    // Description
                    _buildDescription(context, listing),
                    const Divider(height: 32),

                    // Amenities
                    _buildAmenities(context, listing),
                    const Divider(height: 32),

                    // Reviews
                    _buildReviews(context, state),
                    const Divider(height: 32),

                    // House rules
                    if (listing.houseRules.isNotEmpty) ...[
                      _buildHouseRules(context, listing),
                      const Divider(height: 32),
                    ],

                    // Location info
                    if (listing.neighborhoodDesc != null)
                      _buildNeighborhood(context, listing),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
          // Sticky bottom bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: AppShadows.stickyBar,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '\$${listing.pricePerNight.toInt()}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            ' / night',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (state.selectedDates != null)
                        Text(
                          '${state.selectedDates!.nights} nights',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      final dates = state.selectedDates;
                      final checkIn = dates?.start ?? DateTime.now().add(const Duration(days: 7));
                      final checkOut = dates?.end ?? DateTime.now().add(const Duration(days: 10));
                      context.push('/booking', extra: {
                        'listing': listing,
                        'checkIn': checkIn,
                        'checkOut': checkOut,
                        'guests': 1,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: const Text('Reserve'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(top: 4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildHostCard(BuildContext context, ListingModel listing) {
    return GestureDetector(
      onTap: () => context.push('/host/${listing.host.id}'),
      child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.surface,
          child: Text(
            listing.host.firstName[0],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hosted by ${listing.host.fullName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (listing.host.isSuperhost)
                const Text(
                  'Superhost',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ],
    ),
    );
  }

  Widget _buildDescription(BuildContext context, ListingModel listing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(listing.description, style: const TextStyle(fontSize: 16, height: 1.5)),
      ],
    );
  }

  Widget _buildAmenities(BuildContext context, ListingModel listing) {
    const amenityIcons = <String, IconData>{
      'wifi': Icons.wifi,
      'kitchen': Icons.kitchen,
      'pool': Icons.pool,
      'parking': Icons.local_parking,
      'ac': Icons.ac_unit,
      'washer': Icons.local_laundry_service,
      'dryer': Icons.dry_cleaning,
      'gym': Icons.fitness_center,
      'hot_tub': Icons.hot_tub,
      'fireplace': Icons.fireplace,
      'workspace': Icons.desktop_windows,
      'tv': Icons.tv,
      'balcony': Icons.balcony,
      'garden': Icons.yard,
      'bbq': Icons.outdoor_grill,
      'elevator': Icons.elevator,
      'doorman': Icons.security,
    };

    const amenityLabels = <String, String>{
      'wifi': 'Wifi',
      'kitchen': 'Kitchen',
      'pool': 'Pool',
      'parking': 'Free parking',
      'ac': 'Air conditioning',
      'washer': 'Washer',
      'dryer': 'Dryer',
      'gym': 'Gym',
      'hot_tub': 'Hot tub',
      'fireplace': 'Fireplace',
      'workspace': 'Dedicated workspace',
      'tv': 'TV',
      'balcony': 'Balcony',
      'garden': 'Garden',
      'bbq': 'BBQ grill',
      'elevator': 'Elevator',
      'doorman': 'Doorman',
    };

    final displayAmenities = listing.amenities.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What this place offers',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...displayAmenities.map((amenity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    amenityIcons[amenity] ?? Icons.check_circle_outline,
                    size: 24,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    amenityLabels[amenity] ?? amenity,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )),
        if (listing.amenities.length > 8)
          TextButton(
            onPressed: () {},
            child: Text(
              'Show all ${listing.amenities.length} amenities',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReviews(BuildContext context, ListingDetailState state) {
    final listing = state.listing!;
    final averages = state.averages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, size: 20, color: AppColors.star),
            const SizedBox(width: 4),
            Text(
              listing.averageRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              ' · ${state.totalReviews} reviews',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (averages != null) ...[
          const SizedBox(height: 16),
          _buildRatingBar('Cleanliness', averages.cleanliness),
          _buildRatingBar('Accuracy', averages.accuracy),
          _buildRatingBar('Check-in', averages.checkIn),
          _buildRatingBar('Communication', averages.communication),
          _buildRatingBar('Location', averages.location),
          _buildRatingBar('Value', averages.value),
        ],
        const SizedBox(height: 16),
        ...state.reviews.take(2).map((review) => _buildReviewCard(review)),
        if (state.totalReviews > 2)
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(
              'Show all ${state.totalReviews} reviews',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingBar(String label, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (score / 5).clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surface,
                child: Text(
                  review.author.firstName[0],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.author.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatReviewDate(review.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHouseRules(BuildContext context, ListingModel listing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'House rules',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...listing.houseRules.map((rule) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(rule, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildNeighborhood(BuildContext context, ListingModel listing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where you\'ll be',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(listing.latitude, listing.longitude),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(listing.id),
                  position: LatLng(listing.latitude, listing.longitude),
                  infoWindow: InfoWindow(title: listing.title),
                ),
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          listing.neighborhoodDesc!,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  String _formatReviewDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
