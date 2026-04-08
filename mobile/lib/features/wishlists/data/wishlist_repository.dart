import 'package:stayspot/core/api_client.dart';

class WishlistRepository {
  final ApiClient _api = ApiClient();

  Future<List<WishlistModel>> getWishlists() async {
    final response = await _api.dio.get('/wishlists');
    return (response.data['wishlists'] as List)
        .map((e) => WishlistModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishlistModel> createWishlist(String name) async {
    final response = await _api.dio.post('/wishlists', data: {'name': name});
    return WishlistModel.fromJson(response.data['wishlist']);
  }

  Future<void> addListing(String wishlistId, String listingId) async {
    await _api.dio.post('/wishlists/$wishlistId/listings', data: {'listingId': listingId});
  }

  Future<void> removeListing(String wishlistId, String listingId) async {
    await _api.dio.delete('/wishlists/$wishlistId/listings/$listingId');
  }
}

class WishlistModel {
  final String id;
  final String name;
  final int listingCount;
  final String? coverImage;
  final List<WishlistListingPreview> listings;

  const WishlistModel({
    required this.id,
    required this.name,
    this.listingCount = 0,
    this.coverImage,
    this.listings = const [],
  });

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      id: json['id'] as String,
      name: json['name'] as String,
      listingCount: json['listingCount'] as int? ?? 0,
      coverImage: json['coverImage'] as String?,
      listings: (json['listings'] as List?)
              ?.map((e) => WishlistListingPreview.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class WishlistListingPreview {
  final String id;
  final String title;
  final String? imageUrl;

  const WishlistListingPreview({required this.id, required this.title, this.imageUrl});

  factory WishlistListingPreview.fromJson(Map<String, dynamic> json) {
    return WishlistListingPreview(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
