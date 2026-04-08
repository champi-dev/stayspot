import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/core/constants.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class ListingCard extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorited;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorited = false,
  });

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  int _currentImageIndex = 0;
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final imageSize = MediaQuery.of(context).size.width - 32;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image carousel
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: SizedBox(
                  height: imageSize,
                  child: Stack(
                    children: [
                      if (listing.images.isNotEmpty)
                        PageView.builder(
                          itemCount: listing.images.length,
                          onPageChanged: (i) => setState(() => _currentImageIndex = i),
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
                                  child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textTertiary),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.home, size: 64, color: AppColors.textTertiary),
                          ),
                        ),
                      // Pagination dots
                      if (listing.images.length > 1)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              listing.images.length.clamp(0, 5),
                              (i) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _currentImageIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Heart icon
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: widget.onFavoriteTap,
                          child: Icon(
                            widget.isFavorited ? Icons.favorite : Icons.favorite_border,
                            color: widget.isFavorited ? AppColors.primary : Colors.white,
                            size: 28,
                            shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black38),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star, size: 16, color: AppColors.textPrimary),
                        const SizedBox(width: 2),
                        Text(
                          listing.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Property type + location
                    Text(
                      '${listing.propertyTypeLabel}${listing.location != null ? ' · ${listing.location!.name}' : ''}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Row(
                      children: [
                        Text(
                          '\$${listing.pricePerNight.toInt()}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          ' / night',
                          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ],
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
}
