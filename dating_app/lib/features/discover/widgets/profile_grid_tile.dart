import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_distance.dart';
import '../../../data/models/profile.dart';

/// One thumbnail in Grid/Browse mode (spec: Grindr-style scan-many-at-once
/// view, alongside the default swipe deck — see discoverViewModeProvider).
/// Tap opens the full profile; the like button is a quick-action shortcut
/// so grid mode doesn't force a detour through the details sheet just to
/// like someone.
class ProfileGridTile extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const ProfileGridTile({super.key, required this.profile, required this.onTap, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: profile.photoUrls.isNotEmpty ? profile.photoUrls.first : '',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade300),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.isVerified) ...[
                                  const SizedBox(width: 3),
                                  const Icon(Icons.verified, color: AppColors.primary, size: 13),
                                ],
                              ],
                            ),
                            if (formatDistanceKm(profile.distanceKm) != null)
                              Text(
                                formatDistanceKm(profile.distanceKm)!,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: profile.isOnline ? AppColors.success : Colors.grey,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onLike,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
