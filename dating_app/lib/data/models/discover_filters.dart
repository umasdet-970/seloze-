/// Spec section 15: Search & Filters. Basic filters (age, distance,
/// gender) are free; the rest are gated as "Premium filters" — matching
/// the Premium benefits bullet in spec section 8.
enum GenderFilter { everyone, men, women, nonBinary }

extension GenderFilterLabel on GenderFilter {
  String get label => switch (this) {
        GenderFilter.everyone => 'Everyone',
        GenderFilter.men => 'Men',
        GenderFilter.women => 'Women',
        GenderFilter.nonBinary => 'Non-binary',
      };

  bool matches(String profileGender) => switch (this) {
        GenderFilter.everyone => true,
        GenderFilter.men => profileGender == 'Man',
        GenderFilter.women => profileGender == 'Woman',
        GenderFilter.nonBinary => profileGender == 'Non-binary',
      };
}

class DiscoverFilters {
  final String searchQuery;
  final int minAge;
  final int maxAge;
  final double maxDistanceKm;
  final GenderFilter gender;

  // Premium filters.
  final bool verifiedOnly;
  final bool onlineOnly;
  final String profession;
  final String education;
  final Set<String> interests;

  const DiscoverFilters({
    this.searchQuery = '',
    this.minAge = 18,
    this.maxAge = 60,
    this.maxDistanceKm = 100,
    this.gender = GenderFilter.everyone,
    this.verifiedOnly = false,
    this.onlineOnly = false,
    this.profession = '',
    this.education = '',
    this.interests = const {},
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      minAge != 18 ||
      maxAge != 60 ||
      maxDistanceKm != 100 ||
      gender != GenderFilter.everyone ||
      verifiedOnly ||
      onlineOnly ||
      profession.isNotEmpty ||
      education.isNotEmpty ||
      interests.isNotEmpty;

  /// Whether anything differs from [base] — the user's own saved defaults
  /// (see `discoverBaseFiltersProvider`), not the hard-coded ones. Drives
  /// the "filters active" dot on the tune icon: someone who saved 18–45 /
  /// 50 km in onboarding hasn't "applied a filter" just by opening Discover.
  bool differsFrom(DiscoverFilters base) =>
      searchQuery.isNotEmpty ||
      minAge != base.minAge ||
      maxAge != base.maxAge ||
      maxDistanceKm != base.maxDistanceKm ||
      gender != base.gender ||
      verifiedOnly ||
      onlineOnly ||
      profession.isNotEmpty ||
      education.isNotEmpty ||
      interests.isNotEmpty;

  DiscoverFilters copyWith({
    String? searchQuery,
    int? minAge,
    int? maxAge,
    double? maxDistanceKm,
    GenderFilter? gender,
    bool? verifiedOnly,
    bool? onlineOnly,
    String? profession,
    String? education,
    Set<String>? interests,
  }) {
    return DiscoverFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      gender: gender ?? this.gender,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      profession: profession ?? this.profession,
      education: education ?? this.education,
      interests: interests ?? this.interests,
    );
  }
}
