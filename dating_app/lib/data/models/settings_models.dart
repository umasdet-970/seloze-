// Spec section 14: notification settings, privacy settings.

class NotificationPreferences {
  final bool newLikes;
  final bool matches;
  final bool messages;
  final bool promotional;

  const NotificationPreferences({
    this.newLikes = true,
    this.matches = true,
    this.messages = true,
    this.promotional = true,
  });

  NotificationPreferences copyWith({bool? newLikes, bool? matches, bool? messages, bool? promotional}) {
    return NotificationPreferences(
      newLikes: newLikes ?? this.newLikes,
      matches: matches ?? this.matches,
      messages: messages ?? this.messages,
      promotional: promotional ?? this.promotional,
    );
  }
}

class PrivacySettings {
  final bool showOnlineStatus;
  final bool showDistance;

  const PrivacySettings({this.showOnlineStatus = true, this.showDistance = true});

  PrivacySettings copyWith({bool? showOnlineStatus, bool? showDistance}) {
    return PrivacySettings(
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showDistance: showDistance ?? this.showDistance,
    );
  }
}
