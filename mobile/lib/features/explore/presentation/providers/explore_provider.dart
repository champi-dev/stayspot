import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/features/explore/data/explore_repository.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class FilterState {
  final double minPrice;
  final double maxPrice;
  final String? propertyType;
  final int guests;

  const FilterState({
    this.minPrice = 0,
    this.maxPrice = 500,
    this.propertyType,
    this.guests = 1,
  });
}

class ExploreState {
  final List<ListingModel> listings;
  final bool isLoading;
  final bool isGenerating;
  final String? generatingLocation;
  final String? error;
  final List<AutocompleteSuggestion> suggestions;
  final String? selectedLocationName;
  final String? selectedLocationId;
  final FilterState filters;

  const ExploreState({
    this.listings = const [],
    this.isLoading = false,
    this.isGenerating = false,
    this.generatingLocation,
    this.error,
    this.suggestions = const [],
    this.selectedLocationName,
    this.selectedLocationId,
    this.filters = const FilterState(),
  });

  ExploreState copyWith({
    List<ListingModel>? listings,
    bool? isLoading,
    bool? isGenerating,
    Object? generatingLocation = _sentinel,
    String? error,
    List<AutocompleteSuggestion>? suggestions,
    Object? selectedLocationName = _sentinel,
    Object? selectedLocationId = _sentinel,
    FilterState? filters,
  }) {
    return ExploreState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      generatingLocation: generatingLocation == _sentinel
          ? this.generatingLocation
          : generatingLocation as String?,
      error: error,
      suggestions: suggestions ?? this.suggestions,
      selectedLocationName: selectedLocationName == _sentinel
          ? this.selectedLocationName
          : selectedLocationName as String?,
      selectedLocationId: selectedLocationId == _sentinel
          ? this.selectedLocationId
          : selectedLocationId as String?,
      filters: filters ?? this.filters,
    );
  }

  static const _sentinel = Object();
}

class ExploreNotifier extends StateNotifier<ExploreState> {
  final ExploreRepository _repository;
  Timer? _debounce;

  ExploreNotifier(this._repository) : super(const ExploreState());

  Future<void> loadInitialListings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.searchListings(limit: 20);
      state = state.copyWith(listings: result.listings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load listings');
    }
  }

  void searchAutocomplete(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      state = state.copyWith(suggestions: []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final suggestions = await _repository.autocomplete(query);
        state = state.copyWith(suggestions: suggestions);
      } catch (_) {}
    });
  }

  Future<void> selectLocation(AutocompleteSuggestion suggestion) async {
    state = state.copyWith(
      isGenerating: true,
      generatingLocation: suggestion.mainText,
      suggestions: [],
      error: null,
    );
    try {
      final result = await _repository.getLocationListings(suggestion.placeId);
      state = ExploreState(
        listings: result.listings,
        isGenerating: false,
        selectedLocationName: suggestion.description,
        selectedLocationId: result.locationId,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        generatingLocation: null,
        error: 'Failed to load listings for this location',
      );
    }
  }

  Future<void> refreshCurrentListings() async {
    // Reload listings for the current location (or all if no location selected)
    try {
      final result = await _repository.searchListings(
        locationId: state.selectedLocationId,
        minPrice: state.filters.minPrice > 0 ? state.filters.minPrice : null,
        maxPrice: state.filters.maxPrice < 500 ? state.filters.maxPrice : null,
        propertyType: state.filters.propertyType,
        guests: state.filters.guests > 1 ? state.filters.guests : null,
      );
      state = state.copyWith(listings: result.listings);
    } catch (_) {}
  }

  Future<void> applyFilters({
    String? locationId,
    double minPrice = 0,
    double maxPrice = 500,
    String? propertyType,
    int guests = 1,
  }) async {
    final newFilters = FilterState(
      minPrice: minPrice,
      maxPrice: maxPrice,
      propertyType: propertyType,
      guests: guests,
    );
    state = state.copyWith(isLoading: true, error: null, filters: newFilters);
    try {
      final result = await _repository.searchListings(
        locationId: locationId ?? state.selectedLocationId,
        minPrice: minPrice > 0 ? minPrice : null,
        maxPrice: maxPrice < 500 ? maxPrice : null,
        propertyType: propertyType,
        guests: guests > 1 ? guests : null,
      );
      state = state.copyWith(listings: result.listings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to filter listings');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final exploreProvider = StateNotifierProvider<ExploreNotifier, ExploreState>((ref) {
  return ExploreNotifier(ExploreRepository());
});
