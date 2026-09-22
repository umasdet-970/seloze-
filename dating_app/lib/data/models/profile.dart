/// One answered profile prompt (Hinge-style: "A perfect first date looks
/// like..." -> the member's own answer) — see
/// core/constants/profile_prompts.dart for the curated question list.
/// Optional and additive to `bio`, not a replacement for it.
class ProfilePrompt {
  final String question;
  final String answer;

  const ProfilePrompt({required this.question, required this.answer});

  factory ProfilePrompt.fromMap(Map<String, dynamic> map) => ProfilePrompt(
        question: map['question'] as String? ?? '',
        answer: map['answer'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'question': question, 'answer': answer};
}

/// Core profile model. Mirrors what will eventually live in the
/// `users/{uid}` Firestore document. Keeping this as a plain Dart class
/// (not tied to Firestore) means the UI never talks to Firestore directly -
/// only the repository layer does. Swap MockProfileRepository for
/// FirestoreProfileRepository later without touching any widget.
class Profile {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String profession;
  final String company;
  final String education;
  final String bio;
  final List<String> photoUrls;
  final List<String> interests;
  final String city;
  // Kept separate from `city` (a free-text "City, Country" hint in the UI)
  // so the admin dashboard can group users by country exactly (spec
  // section 16/17: country-wise statistics) instead of parsing free text.
  final String country;
  final double distanceKm;
  final bool isOnline;
  final bool isVerified;
  final List<ProfilePrompt> prompts;
  /// Premium's "Boost" (spec: temporary front-of-queue placement) — public
  /// so other users' Discover feeds can sort it first (see
  /// discover_providers.dart), same visibility level as isOnline/
  /// isVerified. Null/past means not currently boosted.
  final DateTime? boostedUntil;
  /// Premium's "Incognito" — hidden from other members' Discover feeds
  /// unless that member already liked this profile (see
  /// discover_providers.dart's filtering). Lives on the public profile
  /// doc, not the private settings doc, because every OTHER member's
  /// feed-building needs to read it per-candidate — it's a visibility
  /// flag, not sensitive data, same class as isOnline/isVerified.
  final bool incognito;

  bool get isBoosted => boostedUntil != null && boostedUntil!.isAfter(DateTime.now());

  const Profile({
    required this.id,
    required this.name,
    required this.age,
    this.gender = '',
    required this.profession,
    required this.company,
    required this.education,
    required this.bio,
    required this.photoUrls,
    required this.interests,
    this.city = '',
    this.country = '',
    required this.distanceKm,
    this.isOnline = false,
    this.isVerified = false,
    this.prompts = const [],
    this.boostedUntil,
    this.incognito = false,
  });

  factory Profile.fromMap(String id, Map<String, dynamic> map) {
    return Profile(
      id: id,
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      gender: map['gender'] as String? ?? '',
      profession: map['profession'] as String? ?? '',
      company: map['company'] as String? ?? '',
      education: map['education'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      photoUrls: List<String>.from(map['photoUrls'] as List? ?? []),
      interests: List<String>.from(map['interests'] as List? ?? []),
      city: map['city'] as String? ?? '',
      country: map['country'] as String? ?? '',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      isOnline: map['isOnline'] as bool? ?? false,
      isVerified: map['isVerified'] as bool? ?? false,
      prompts: (map['prompts'] as List? ?? const [])
          .map((p) => ProfilePrompt.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
      boostedUntil: (map['boostedUntil'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch((map['boostedUntil'] as num).toInt())
          : null,
      incognito: map['incognito'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender,
        'profession': profession,
        'company': company,
        'education': education,
        'bio': bio,
        'photoUrls': photoUrls,
        'interests': interests,
        'city': city,
        'country': country,
        'distanceKm': distanceKm,
        'isOnline': isOnline,
        'isVerified': isVerified,
        'prompts': prompts.map((p) => p.toMap()).toList(),
        // Millis, not a Firestore Timestamp — this model is shared by the
        // Mock repo too, and staying a plain number keeps fromMap's parsing
        // (`as num?`) identical for both, rather than branching on
        // Firestore's Timestamp type only here. UserProfileRepository
        // writes/reads this field directly (not through toMap/fromMap on
        // the whole profile), so this key mainly matters for round-trip
        // tests and any future caller that does serialize via toMap.
        if (boostedUntil != null) 'boostedUntil': boostedUntil!.millisecondsSinceEpoch,
        'incognito': incognito,
      };

  Profile copyWith({
    String? name,
    int? age,
    String? gender,
    String? profession,
    String? company,
    String? education,
    String? bio,
    List<String>? photoUrls,
    List<String>? interests,
    String? city,
    String? country,
    double? distanceKm,
    bool? isOnline,
    bool? isVerified,
    List<ProfilePrompt>? prompts,
    DateTime? boostedUntil,
    bool? incognito,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      profession: profession ?? this.profession,
      company: company ?? this.company,
      education: education ?? this.education,
      bio: bio ?? this.bio,
      photoUrls: photoUrls ?? this.photoUrls,
      interests: interests ?? this.interests,
      city: city ?? this.city,
      country: country ?? this.country,
      distanceKm: distanceKm ?? this.distanceKm,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      prompts: prompts ?? this.prompts,
      boostedUntil: boostedUntil ?? this.boostedUntil,
      incognito: incognito ?? this.incognito,
    );
  }
}
