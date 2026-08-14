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
  final double distanceKm;
  final bool isOnline;
  final bool isVerified;

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
    required this.distanceKm,
    this.isOnline = false,
    this.isVerified = false,
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
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      isOnline: map['isOnline'] as bool? ?? false,
      isVerified: map['isVerified'] as bool? ?? false,
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
        'distanceKm': distanceKm,
        'isOnline': isOnline,
        'isVerified': isVerified,
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
    double? distanceKm,
    bool? isOnline,
    bool? isVerified,
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
      distanceKm: distanceKm ?? this.distanceKm,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
