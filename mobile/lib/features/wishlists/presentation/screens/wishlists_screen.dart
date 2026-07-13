import 'package:flutter/material.dart';
import 'package:stayspot/shared/widgets/app_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/core/constants.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/wishlists/data/wishlist_repository.dart';
import 'package:stayspot/features/wishlists/presentation/providers/wishlist_provider.dart';

class WishlistsScreen extends ConsumerStatefulWidget {
  const WishlistsScreen({super.key});

  @override
  ConsumerState<WishlistsScreen> createState() => _WishlistsScreenState();
}

class _WishlistsScreenState extends ConsumerState<WishlistsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated) {
        ref.read(wishlistProvider.notifier).loadWishlists();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final wishlists = ref.watch(wishlistProvider);

    if (auth.status != AuthStatus.authenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_outline, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('Wishlists', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                const Text('Log in to see your wishlists', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlists')),
      body: wishlists.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : wishlists.wishlists.isEmpty
              ? _buildEmptyState()
              : _buildWishlistGrid(wishlists),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline, size: 64, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('No wishlists yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Tap the heart on any listing to save it here',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistGrid(WishlistState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: state.wishlists.length,
      itemBuilder: (context, index) {
        final wishlist = state.wishlists[index];
        return GestureDetector(
          onTap: () => _openWishlistDetail(wishlist),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: wishlist.coverImage != null
                      ? AppNetworkImage('${ApiConstants.imageBaseUrl}${wishlist.coverImage}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : _placeholderCover(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                wishlist.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${wishlist.listingCount} saved',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholderCover() {
    return Container(
      color: AppColors.surface,
      width: double.infinity,
      child: const Center(child: Icon(Icons.favorite, size: 32, color: AppColors.textTertiary)),
    );
  }

  void _openWishlistDetail(WishlistModel wishlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _WishlistDetailSheet(wishlist: wishlist),
      ),
    );
  }
}

class _WishlistDetailSheet extends StatelessWidget {
  final WishlistModel wishlist;

  const _WishlistDetailSheet({required this.wishlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(wishlist.name),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: wishlist.listings.isEmpty
          ? const Center(
              child: Text('No listings saved yet', style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: wishlist.listings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final listing = wishlist.listings[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/listing/${listing.id}');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                          child: listing.imageUrl != null
                              ? AppNetworkImage('${ApiConstants.imageBaseUrl}${listing.imageUrl}',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 100, height: 100, color: AppColors.surface,
                                  child: const Icon(Icons.home, color: AppColors.textTertiary),
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              listing.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
