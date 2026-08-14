/// Private to the owner — used to filter the Discover feed, never shown
/// on a profile card. Distinct from [Profile], which is what other users
/// see (spec section 2: dating intention, relationship preference, age
/// preference, distance preference, profile visibility).
enum DatingIntention { longTerm, shortTerm, friendship, notSure }

extension DatingIntentionLabel on DatingIntention {
  String get label => switch (this) {
        DatingIntention.longTerm => 'Long-term relationship',
        DatingIntention.shortTerm => 'Short-term fun',
        DatingIntention.friendship => 'New friends',
        DatingIntention.notSure => 'Still figuring it out',
      };
}

enum RelationshipPreference { monogamous, nonMonogamous, notSure }

extension RelationshipPreferenceLabel on RelationshipPreference {
  String get label => switch (this) {
        RelationshipPreference.monogamous => 'Monogamous',
        RelationshipPreference.nonMonogamous => 'Non-monogamous',
        RelationshipPreference.notSure => 'Not sure yet',
      };
}

enum ShowMePreference { men, women, everyone }

extension ShowMePreferenceLabel on ShowMePreference {
  String get label => switch (this) {
        ShowMePreference.men => 'Men',
        ShowMePreference.women => 'Women',
        ShowMePreference.everyone => 'Everyone',
      };
}

class DatingPreferences {
  final DatingIntention intention;
  final RelationshipPreference relationshipPreference;
  final ShowMePreference showMe;
  final int minAge;
  final int maxAge;
  final double maxDistanceKm;
  final bool profileVisible;

  const DatingPreferences({
    this.intention = DatingIntention.notSure,
    this.relationshipPreference = RelationshipPreference.notSure,
    this.showMe = ShowMePreference.everyone,
    this.minAge = 18,
    this.maxAge = 45,
    this.maxDistanceKm = 50,
    this.profileVisible = true,
  });

  DatingPreferences copyWith({
    DatingIntention? intention,
    RelationshipPreference? relationshipPreference,
    ShowMePreference? showMe,
    int? minAge,
    int? maxAge,
    double? maxDistanceKm,
    bool? profileVisible,
  }) {
    return DatingPreferences(
      intention: intention ?? this.intention,
      relationshipPreference: relationshipPreference ?? this.relationshipPreference,
      showMe: showMe ?? this.showMe,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      profileVisible: profileVisible ?? this.profileVisible,
    );
  }
}
