class Branch {
  final int id;
  final String name;
  final String description;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;
  final String phone;
  final String email;
  final String openingTime;
  final String closingTime;
  final bool isActive;
  final List<String> images;
  final String createdAt;
  final double? distanceKm;

  const Branch({
    required this.id,
    required this.name,
    this.description = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.latitude,
    this.longitude,
    this.phone = '',
    this.email = '',
    this.openingTime = '08:00',
    this.closingTime = '22:00',
    this.isActive = true,
    this.images = const [],
    this.createdAt = '',
    this.distanceKm,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      openingTime: json['opening_time'] as String? ?? '08:00',
      closingTime: json['closing_time'] as String? ?? '22:00',
      isActive: json['is_active'] as bool? ?? true,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  String get fullAddress {
    final parts = [address, city, state].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  String get distanceText {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m';
    return '${distanceKm!.toStringAsFixed(1)} km';
  }
}
