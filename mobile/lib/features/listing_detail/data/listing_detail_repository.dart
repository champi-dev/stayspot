import 'package:stayspot/core/api_client.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class ListingDetailRepository {
  final ApiClient _api = ApiClient();

  Future<ListingModel> getListingById(String id) async {
    final response = await _api.dio.get('/listings/$id');
    return ListingModel.fromJson(response.data['listing']);
  }

  Future<List<String>> getAvailability(String listingId, int month, int year) async {
    final response = await _api.dio.get(
      '/listings/$listingId/availability',
      queryParameters: {'month': month, 'year': year},
    );
    return List<String>.from(response.data['bookedDates']);
  }

  Future<ReviewsResult> getReviews(String listingId, {int page = 1, int limit = 10}) async {
    final response = await _api.dio.get(
      '/listings/$listingId/reviews',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    return ReviewsResult(
      reviews: (data['reviews'] as List)
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      averages: ReviewAverages.fromJson(data['averages']),
      total: data['pagination']['total'] as int,
    );
  }
}

class ReviewModel {
  final String id;
  final double rating;
  final String comment;
  final double cleanliness;
  final double accuracy;
  final double checkIn;
  final double communication;
  final double location;
  final double value;
  final DateTime createdAt;
  final ReviewAuthor author;

  const ReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.cleanliness,
    required this.accuracy,
    required this.checkIn,
    required this.communication,
    required this.location,
    required this.value,
    required this.createdAt,
    required this.author,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      cleanliness: (json['cleanliness'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      checkIn: (json['checkIn'] as num).toDouble(),
      communication: (json['communication'] as num).toDouble(),
      location: (json['location'] as num).toDouble(),
      value: (json['value'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      author: ReviewAuthor.fromJson(json['author'] as Map<String, dynamic>),
    );
  }
}

class ReviewAuthor {
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  const ReviewAuthor({required this.firstName, required this.lastName, this.avatarUrl});

  String get fullName => '$firstName $lastName';

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReviewAuthor(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class ReviewAverages {
  final double rating;
  final double cleanliness;
  final double accuracy;
  final double checkIn;
  final double communication;
  final double location;
  final double value;

  const ReviewAverages({
    required this.rating,
    required this.cleanliness,
    required this.accuracy,
    required this.checkIn,
    required this.communication,
    required this.location,
    required this.value,
  });

  factory ReviewAverages.fromJson(Map<String, dynamic> json) {
    return ReviewAverages(
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      cleanliness: (json['cleanliness'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      checkIn: (json['checkIn'] as num?)?.toDouble() ?? 0,
      communication: (json['communication'] as num?)?.toDouble() ?? 0,
      location: (json['location'] as num?)?.toDouble() ?? 0,
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReviewsResult {
  final List<ReviewModel> reviews;
  final ReviewAverages averages;
  final int total;

  const ReviewsResult({required this.reviews, required this.averages, required this.total});
}
