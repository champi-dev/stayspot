import 'package:stayspot/core/api_client.dart';

class BookingRepository {
  final ApiClient _api = ApiClient();

  Future<BookingModel> createBooking({
    required String listingId,
    required String checkIn,
    required String checkOut,
    required int guests,
  }) async {
    final response = await _api.dio.post('/bookings', data: {
      'listingId': listingId,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'guests': guests,
    });
    return BookingModel.fromJson(response.data['booking']);
  }

  Future<BookingModel> confirmBooking(String bookingId) async {
    final response = await _api.dio.post('/bookings/$bookingId/confirm');
    return BookingModel.fromJson(response.data['booking']);
  }

  Future<BookingsResult> getUserBookings() async {
    final response = await _api.dio.get('/bookings');
    return BookingsResult(
      upcoming: (response.data['upcoming'] as List)
          .map((e) => BookingModel.fromJson(e))
          .toList(),
      past: (response.data['past'] as List)
          .map((e) => BookingModel.fromJson(e))
          .toList(),
    );
  }

  Future<void> cancelBooking(String bookingId) async {
    await _api.dio.delete('/bookings/$bookingId');
  }
}

class BookingModel {
  final String id;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final BookingListing? listing;

  const BookingModel({
    required this.id,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.listing,
  });

  int get nights => checkOut.difference(checkIn).inDays;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      checkIn: DateTime.parse(json['checkIn'] as String),
      checkOut: DateTime.parse(json['checkOut'] as String),
      guests: json['guests'] as int,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      listing: json['listing'] != null
          ? BookingListing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BookingListing {
  final String id;
  final String title;
  final double pricePerNight;
  final double cleaningFee;
  final double serviceFee;
  final String? imageUrl;
  final String? locationName;

  const BookingListing({
    required this.id,
    required this.title,
    required this.pricePerNight,
    this.cleaningFee = 25,
    this.serviceFee = 15,
    this.imageUrl,
    this.locationName,
  });

  factory BookingListing.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as List?;
    final location = json['location'] as Map<String, dynamic>?;
    return BookingListing(
      id: json['id'] as String,
      title: json['title'] as String,
      pricePerNight: (json['pricePerNight'] as num).toDouble(),
      cleaningFee: (json['cleaningFee'] as num?)?.toDouble() ?? 25,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 15,
      imageUrl: images != null && images.isNotEmpty ? images[0]['url'] as String? : null,
      locationName: location?['name'] as String?,
    );
  }
}

class BookingsResult {
  final List<BookingModel> upcoming;
  final List<BookingModel> past;

  const BookingsResult({required this.upcoming, required this.past});
}
