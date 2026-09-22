import 'package:flutter/material.dart';

/// Spec section 13. `newMessage`/`subscriptionRenewal`/`subscriptionExpiration`
/// are modeled here but not live-triggered yet — they need a chat listener
/// that runs outside the open conversation and a real elapsed-time/cron
/// signal respectively, both of which need the Firebase phase.
enum NotificationType {
  newLike,
  mutualMatch,
  newMessage,
  profileVerification,
  reportUpdate,
  subscriptionPurchase,
  subscriptionRenewal,
  subscriptionExpiration,
  securityAlert,
  promotional,
  referralReward,
  roseReceived,
}

extension NotificationTypeMeta on NotificationType {
  IconData get icon => switch (this) {
        NotificationType.newLike => Icons.favorite,
        NotificationType.mutualMatch => Icons.celebration,
        NotificationType.newMessage => Icons.chat_bubble,
        NotificationType.profileVerification => Icons.verified,
        NotificationType.reportUpdate => Icons.flag,
        NotificationType.subscriptionPurchase ||
        NotificationType.subscriptionRenewal ||
        NotificationType.subscriptionExpiration =>
          Icons.workspace_premium,
        NotificationType.securityAlert => Icons.shield,
        NotificationType.promotional => Icons.campaign,
        NotificationType.referralReward => Icons.group_add,
        NotificationType.roseReceived => Icons.local_florist,
      };

  /// Route to open when tapped, if any.
  String? get route => switch (this) {
        NotificationType.newLike || NotificationType.roseReceived => '/likes',
        NotificationType.mutualMatch => '/matches',
        NotificationType.newMessage => '/chat',
        NotificationType.profileVerification || NotificationType.referralReward => '/profile',
        NotificationType.subscriptionPurchase ||
        NotificationType.subscriptionRenewal ||
        NotificationType.subscriptionExpiration =>
          '/paywall',
        _ => null,
      };
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  NotificationItem copyWith({bool? read}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }
}
