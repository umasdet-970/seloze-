/// Invite-a-friend rewards. Keep [kBonusDiscoveriesPerFriend] and
/// [kMaxRewardedFriends] in sync with `functions/src/referrals.ts`.
///
/// How it works: a user shares a Play Store link carrying their uid in the
/// install referrer. A friend who installs through it is recorded as
/// `invitedBy` at sign-up; once that friend completes their profile, a Cloud
/// Function credits the inviter, and the app turns the count into extra
/// daily discoveries.
const int kBonusDiscoveriesPerFriend = 5;
const int kMaxRewardedFriends = 5;

const String kPlayStorePackage = 'com.connect.connect_dating_app';

/// Extra daily discoveries earned from [friendsJoined] invited friends,
/// capped at [kMaxRewardedFriends] friends.
int referralBonus(int friendsJoined) =>
    friendsJoined.clamp(0, kMaxRewardedFriends) * kBonusDiscoveriesPerFriend;

/// The Play Store link a user shares. The `referrer` value is what Google's
/// Install Referrer API hands to the app on first launch — parsed by
/// `AcquisitionSourceService.parseReferrer`. Only works for installs that
/// go through the Play Store listing.
String buildInviteLink(String inviterUid) {
  final referrer = 'utm_source=invite&utm_content=$inviterUid';
  return 'https://play.google.com/store/apps/details?id=$kPlayStorePackage'
      '&referrer=${Uri.encodeComponent(referrer)}';
}
