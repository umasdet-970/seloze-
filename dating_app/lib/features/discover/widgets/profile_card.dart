import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/profile.dart';

class ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback? onInfoTap;
  final VoidCallback? onMenuTap;

  const ProfileCard({super.key, required this.profile, this.onInfoTap, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade300),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 80, color: Colors.white),
            ),
          ),

          // gradient for text legibility
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                ),
              ),
            ),
          ),

          // top badges: online + distance
          Positioned(
            top: 16,
            left: 16,
            child: _Badge(
              icon: Icons.circle,
              iconColor: profile.isOnline ? AppColors.success : Colors.grey,
              label: profile.isOnline ? 'Online' : 'Offline',
              iconSize: 8,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: [
                _Badge(
                  icon: Icons.location_on,
                  iconColor: Colors.white,
                  label: '${profile.distanceKm} km',
                ),
                if (onMenuTap != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onMenuTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // info button
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: onInfoTap,
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                child: Icon(Icons.info_outline, color: Colors.black87, size: 20),
              ),
            ),
          ),

          // name / age / bio / chips
          Positioned(
            left: 20,
            right: 80,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${profile.name}, ${profile.age}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.primary, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (profile.profession.isNotEmpty)
                  _IconLine(icon: Icons.work_outline, text: '${profile.profession} at ${profile.company}'),
                if (profile.education.isNotEmpty)
                  _IconLine(icon: Icons.school_outlined, text: profile.education),
                const SizedBox(height: 6),
                Text(
                  profile.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final interest in profile.interests.take(3))
                      _Chip(label: interest),
                    if (profile.interests.length > 3)
                      _Chip(label: '+${profile.interests.length - 3}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double iconSize;

  const _Badge({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}
