import 'package:stayspot/core/api_client.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class ExploreRepository {
  final ApiClient _api = ApiClient();

  Future<List<AutocompleteSuggestion>> autocomplete(String query) async {
    final response = await _api.dio.get('/locations/autocomplete', queryParameters: {'q': query});
    return (response.data as List)
        .map((e) => AutocompleteSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LocationSearchResult> getLocationListings(String placeId) async {
    final response = await _api.dio.get('/locations/$placeId');
    final data = response.data;
    final listings = (data['listings'] as List)
        .map((e) => ListingModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return LocationSearchResult(
      locationName: data['location']?['name'] as String? ?? '',
      locationId: data['location']?['id'] as String?,
      listings: listings,
    );
  }

  Future<ListingsSearchResult> searchListings({
    String? locationId,
    double? minPrice,
    double? maxPrice,
    String? propertyType,
    int? guests,
    List<String>? amenities,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (locationId != null) params['locationId'] = locationId;
    if (minPrice != null) params['minPrice'] = minPrice;
    if (maxPrice != null) params['maxPrice'] = maxPrice;
    if (propertyType != null) params['propertyType'] = propertyType;
    if (guests != null) params['guests'] = guests;
    if (amenities != null && amenities.isNotEmpty) {
      params['amenities'] = amenities.join(',');
    }

    final response = await _api.dio.get('/listings', queryParameters: params);
    final data = response.data;
    final listings = (data['listings'] as List)
        .map((e) => ListingModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ListingsSearchResult(
      listings: listings,
      total: data['pagination']['total'] as int,
      totalPages: data['pagination']['totalPages'] as int,
    );
  }
}

class LocationSearchResult {
  final String locationName;
  final String? locationId;
  final List<ListingModel> listings;

  const LocationSearchResult({required this.locationName, this.locationId, required this.listings});
}

class ListingsSearchResult {
  final List<ListingModel> listings;
  final int total;
  final int totalPages;

  const ListingsSearchResult({
    required this.listings,
    required this.total,
    required this.totalPages,
  });
}
