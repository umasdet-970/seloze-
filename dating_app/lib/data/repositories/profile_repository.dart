import '../models/profile.dart';

/// Contract the UI/providers depend on. When you're ready to plug in
/// Firebase, write `FirestoreProfileRepository implements ProfileRepository`
/// and swap it in `discover_providers.dart` — nothing else changes.
///
/// Scope: fetching OTHER users' candidate cards only. Swipe/match state
/// lives in [SocialRepository]; your own profile lives in
/// [UserProfileRepository].
abstract class ProfileRepository {
  Future<List<Profile>> fetchDiscoverFeed({required String currentUserId});

  /// Resolves a single candidate by id — used by Likes/Matches screens to
  /// render "who liked you" / "your matches" from ids stored in
  /// [SocialRepository].
  Future<Profile?> fetchProfileById(String id);
}

class MockProfileRepository implements ProfileRepository {
  static final _mockFeed = <Profile>[
    const Profile(
      id: 'u1',
      name: 'Ananya',
      age: 24,
      gender: 'Woman',
      profession: 'UX Designer',
      company: 'Pixelverse',
      education: 'Symbiosis University',
      bio: 'Coffee lover ☕ | Dog person 🐾 | Travel & good vibes ✨',
      photoUrls: ['https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800'],
      interests: ['Travel', 'Music', 'Dogs', 'Coffee', 'Design'],
      city: 'Mumbai',
      distanceKm: 1.2,
      isOnline: true,
      isVerified: true,
    ),
    const Profile(
      id: 'u2',
      name: 'Rohan',
      age: 27,
      gender: 'Man',
      profession: 'Software Engineer',
      company: 'Microsoft',
      education: 'IIT Bombay',
      bio: 'Building things, chasing sunsets 🌅',
      photoUrls: ['https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800'],
      interests: ['Tech', 'Hiking', 'Photography'],
      city: 'Pune',
      distanceKm: 3.4,
      isOnline: false,
      isVerified: true,
    ),
    const Profile(
      id: 'u3',
      name: 'Meera',
      age: 25,
      gender: 'Woman',
      profession: 'Marketing Lead',
      company: 'Zomato',
      education: 'NMIMS',
      bio: 'Foodie, bookworm, occasional karaoke queen 🎤',
      photoUrls: ['https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=800'],
      interests: ['Books', 'Food', 'Karaoke'],
      city: 'Bengaluru',
      distanceKm: 5.1,
      isOnline: true,
      isVerified: false,
    ),
    const Profile(
      id: 'u4',
      name: 'Kabir',
      age: 29,
      gender: 'Man',
      profession: 'Product Manager',
      company: 'Razorpay',
      education: 'IIM Ahmedabad',
      bio: 'Weekend trekker, weekday spreadsheet warrior 🏔️',
      photoUrls: ['https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800'],
      interests: ['Hiking', 'Startups', 'Cooking'],
      city: 'Delhi',
      distanceKm: 6.8,
      isOnline: false,
      isVerified: true,
    ),
    const Profile(
      id: 'u5',
      name: 'Priya',
      age: 26,
      gender: 'Woman',
      profession: 'Doctor',
      company: 'Fortis Hospital',
      education: 'AIIMS Delhi',
      bio: 'Saving lives by day, Netflix by night 🩺',
      photoUrls: ['https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=800'],
      interests: ['Movies', 'Yoga', 'Reading'],
      city: 'Delhi',
      distanceKm: 2.3,
      isOnline: true,
      isVerified: true,
    ),
    const Profile(
      id: 'u6',
      name: 'Arjun',
      age: 28,
      gender: 'Man',
      profession: 'Chef',
      company: 'The Bombay Canteen',
      education: 'Culinary Institute',
      bio: 'I will cook for you. That is my whole pitch. 🍝',
      photoUrls: ['https://images.unsplash.com/photo-1521119989659-a83eee488004?w=800'],
      interests: ['Cooking', 'Food', 'Wine'],
      city: 'Mumbai',
      distanceKm: 4.5,
      isOnline: true,
      isVerified: false,
    ),
    const Profile(
      id: 'u7',
      name: 'Sneha',
      age: 23,
      gender: 'Woman',
      profession: 'Graphic Designer',
      company: 'Freelance',
      education: 'NID Ahmedabad',
      bio: 'Colors, coffee, and chaotic good energy ✨',
      photoUrls: ['https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800'],
      interests: ['Art', 'Design', 'Coffee', 'Music'],
      city: 'Ahmedabad',
      distanceKm: 8.1,
      isOnline: false,
      isVerified: true,
    ),
    const Profile(
      id: 'u8',
      name: 'Vikram',
      age: 31,
      gender: 'Man',
      profession: 'Fitness Coach',
      company: 'Cult.fit',
      education: 'Delhi University',
      bio: 'Gym in the morning, biryani at night. Balance. 💪',
      photoUrls: ['https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800'],
      interests: ['Fitness', 'Travel', 'Food'],
      city: 'Bengaluru',
      distanceKm: 3.9,
      isOnline: true,
      isVerified: false,
    ),
    const Profile(
      id: 'u9',
      name: 'Ishita',
      age: 27,
      gender: 'Woman',
      profession: 'Lawyer',
      company: 'Khaitan & Co',
      education: 'NLSIU Bangalore',
      bio: 'Arguing for a living, dancing for fun 💃',
      photoUrls: ['https://images.unsplash.com/photo-1544717305-2782549b5136?w=800'],
      interests: ['Dancing', 'Reading', 'Travel'],
      city: 'Bengaluru',
      distanceKm: 1.7,
      isOnline: false,
      isVerified: true,
    ),
    const Profile(
      id: 'u10',
      name: 'Dev',
      age: 25,
      gender: 'Man',
      profession: 'Musician',
      company: 'Independent',
      education: 'KM Music Conservatory',
      bio: 'I write songs about people who ghost me. No pressure. 🎸',
      photoUrls: ['https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800'],
      interests: ['Music', 'Gaming', 'Movies'],
      city: 'Chennai',
      distanceKm: 7.2,
      isOnline: true,
      isVerified: false,
    ),
  ];

  @override
  Future<List<Profile>> fetchDiscoverFeed({required String currentUserId}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockFeed.where((p) => p.id != currentUserId).toList();
  }

  @override
  Future<Profile?> fetchProfileById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (final p in _mockFeed) {
      if (p.id == id) return p;
    }
    return null;
  }
}
