import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/core/notifications_service.dart';
import 'package:stayspot/features/booking/data/booking_repository.dart';

class BookingState {
  final List<BookingModel> upcoming;
  final List<BookingModel> past;
  final bool isLoading;
  final String? error;

  const BookingState({
    this.upcoming = const [],
    this.past = const [],
    this.isLoading = false,
    this.error,
  });

  BookingState copyWith({
    List<BookingModel>? upcoming,
    List<BookingModel>? past,
    bool? isLoading,
    String? error,
  }) {
    return BookingState(
      upcoming: upcoming ?? this.upcoming,
      past: past ?? this.past,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  final BookingRepository _repository;

  BookingNotifier(this._repository) : super(const BookingState());

  Future<void> loadBookings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.getUserBookings();
      state = state.copyWith(
        upcoming: result.upcoming,
        past: result.past,
        isLoading: false,
      );
      // Keep an on-device reminder scheduled for every upcoming trip
      for (final booking in result.upcoming) {
        NotificationsService.instance.scheduleTripReminder(
          bookingId: booking.id,
          listingTitle: booking.listing?.title ?? 'your stay',
          checkIn: booking.checkIn,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load bookings');
    }
  }

  Future<BookingModel?> createAndConfirmBooking({
    required String listingId,
    required String checkIn,
    required String checkOut,
    required int guests,
  }) async {
    try {
      final booking = await _repository.createBooking(
        listingId: listingId,
        checkIn: checkIn,
        checkOut: checkOut,
        guests: guests,
      );
      final confirmed = await _repository.confirmBooking(booking.id);
      await loadBookings();
      return confirmed;
    } catch (_) {
      return null;
    }
  }

  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _repository.cancelBooking(bookingId);
      NotificationsService.instance.cancelTripReminder(bookingId);
      await loadBookings();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(BookingRepository());
});
