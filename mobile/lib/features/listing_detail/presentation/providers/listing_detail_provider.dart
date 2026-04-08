import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/features/listing_detail/data/listing_detail_repository.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class ListingDetailState {
  final ListingModel? listing;
  final bool isLoading;
  final String? error;
  final List<ReviewModel> reviews;
  final ReviewAverages? averages;
  final int totalReviews;
  final DateTimeRange? selectedDates;

  const ListingDetailState({
    this.listing,
    this.isLoading = false,
    this.error,
    this.reviews = const [],
    this.averages,
    this.totalReviews = 0,
    this.selectedDates,
  });

  ListingDetailState copyWith({
    ListingModel? listing,
    bool? isLoading,
    String? error,
    List<ReviewModel>? reviews,
    ReviewAverages? averages,
    int? totalReviews,
    DateTimeRange? selectedDates,
  }) {
    return ListingDetailState(
      listing: listing ?? this.listing,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      reviews: reviews ?? this.reviews,
      averages: averages ?? this.averages,
      totalReviews: totalReviews ?? this.totalReviews,
      selectedDates: selectedDates ?? this.selectedDates,
    );
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});

  int get nights => end.difference(start).inDays;
}

class ListingDetailNotifier extends StateNotifier<ListingDetailState> {
  final ListingDetailRepository _repository;

  ListingDetailNotifier(this._repository) : super(const ListingDetailState());

  Future<void> loadListing(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final listing = await _repository.getListingById(id);
      final reviewsResult = await _repository.getReviews(id, limit: 6);
      state = state.copyWith(
        listing: listing,
        reviews: reviewsResult.reviews,
        averages: reviewsResult.averages,
        totalReviews: reviewsResult.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load listing');
    }
  }

  void setDates(DateTime start, DateTime end) {
    state = state.copyWith(selectedDates: DateTimeRange(start: start, end: end));
  }
}

final listingDetailProvider =
    StateNotifierProvider.family<ListingDetailNotifier, ListingDetailState, String>(
  (ref, id) {
    final notifier = ListingDetailNotifier(ListingDetailRepository());
    notifier.loadListing(id);
    return notifier;
  },
);
