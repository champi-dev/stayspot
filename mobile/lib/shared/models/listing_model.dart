class ListingModel {
  final String id;
  final String title;
  final String description;
  final String propertyType;
  final double pricePerNight;
  final double cleaningFee;
  final double serviceFee;
  final int maxGuests;
  final int bedrooms;
  final int beds;
  final double bathrooms;
  final List<String> amenities;
  final List<String> houseRules;
  final String checkInTime;
  final String checkOutTime;
  final String? neighborhoodDesc;
  final double latitude;
  final double longitude;
  final double averageRating;
  final int reviewCount;
  final String hostId;
  final HostInfo host;
  final LocationInfo? location;
  final List<ListingImage> images;

  const ListingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.pricePerNight,
    this.cleaningFee = 25,
    this.serviceFee = 15,
    required this.maxGuests,
    required this.bedrooms,
    required this.beds,
    required this.bathrooms,
    required this.amenities,
    this.houseRules = const [],
    this.checkInTime = '15:00',
    this.checkOutTime = '11:00',
    this.neighborhoodDesc,
    required this.latitude,
    required this.longitude,
    this.averageRating = 0,
    this.reviewCount = 0,
    required this.hostId,
    required this.host,
    this.location,
    this.images = const [],
  });

  String get propertyTypeLabel {
    switch (propertyType) {
      case 'ENTIRE_PLACE':
        return 'Entire place';
      case 'PRIVATE_ROOM':
        return 'Private room';
      case 'SHARED_ROOM':
        return 'Shared room';
      case 'HOTEL_ROOM':
        return 'Hotel room';
      default:
        return propertyType;
    }
  }

  String get statsText =>
      '$maxGuests guests · $bedrooms bedrooms · $beds beds · ${bathrooms % 1 == 0 ? bathrooms.toInt() : bathrooms} baths';

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    return ListingModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      propertyType: json['propertyType'] as String,
      pricePerNight: (json['pricePerNight'] as num).toDouble(),
      cleaningFee: (json['cleaningFee'] as num?)?.toDouble() ?? 25,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 15,
      maxGuests: json['maxGuests'] as int,
      bedrooms: json['bedrooms'] as int,
      beds: json['beds'] as int,
      bathrooms: (json['bathrooms'] as num).toDouble(),
      amenities: List<String>.from(json['amenities'] ?? []),
      houseRules: List<String>.from(json['houseRules'] ?? []),
      checkInTime: json['checkInTime'] as String? ?? '15:00',
      checkOutTime: json['checkOutTime'] as String? ?? '11:00',
      neighborhoodDesc: json['neighborhoodDesc'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      hostId: json['hostId'] as String,
      host: HostInfo.fromJson(json['host'] as Map<String, dynamic>),
      location: json['location'] != null
          ? LocationInfo.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ListingImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ListingImage {
  final String id;
  final String url;
  final String? caption;
  final int sortOrder;

  const ListingImage({
    required this.id,
    required this.url,
    this.caption,
    this.sortOrder = 0,
  });

  factory ListingImage.fromJson(Map<String, dynamic> json) {
    return ListingImage(
      id: json['id'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class HostInfo {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final bool isSuperhost;
  final String? bio;
  final DateTime? createdAt;

  const HostInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.isSuperhost = false,
    this.bio,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory HostInfo.fromJson(Map<String, dynamic> json) {
    return HostInfo(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isSuperhost: json['isSuperhost'] as bool? ?? false,
      bio: json['bio'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

class LocationInfo {
  final String? name;
  final String? country;

  const LocationInfo({this.name, this.country});

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      name: json['name'] as String?,
      country: json['country'] as String?,
    );
  }
}

class AutocompleteSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const AutocompleteSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory AutocompleteSuggestion.fromJson(Map<String, dynamic> json) {
    return AutocompleteSuggestion(
      placeId: json['placeId'] as String,
      description: json['description'] as String,
      mainText: json['mainText'] as String,
      secondaryText: json['secondaryText'] as String,
    );
  }
}
