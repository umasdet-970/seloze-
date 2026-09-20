import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_distance.dart';
import '../../../data/models/profile.dart';

/// Opened by the (i) button on a Discover card: the full profile (all
/// photos, full bio, every interest) instead of the card's 2-line summary.
Future<void> showProfileDetailsSheet(BuildContext context, Profile profile) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => _ProfileDetails(profile: profile, controller: controller),
    ),
  );
}

class _ProfileDetails extends StatelessWidget {
  final Profile profile;
  final ScrollController controller;
  const _ProfileDetails({required this.profile, required this.controller});

  @override
  Widget build(BuildContext context) {
    final distance = formatDistanceKm(profile.distanceKm);
    final location = [profile.city, profile.country].where((s) => s.isNotEmpty).join(', ');
    final work = profile.profession.isEmpty
        ? null
        : (profile.company.isEmpty ? profile.profession : '${profile.profession} at ${profile.company}');

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        if (profile.photoUrls.isNotEmpty)
          SizedBox(
            height: 320,
            child: PageView.builder(
              itemCount: profile.photoUrls.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: profile.photoUrls[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey.shade300),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.person, size: 80, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (profile.photoUrls.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Center(
              child: Text('Swipe for more photos', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Flexible(
              child: Text(
                '${profile.name}, ${profile.age}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (profile.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: AppColors.primary, size: 22),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (location.isNotEmpty || distance != null)
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: [if (location.isNotEmpty) location, if (distance != null) distance].join(' · '),
          ),
        if (work != null) _InfoRow(icon: Icons.work_outline, text: work),
        if (profile.education.isNotEmpty) _InfoRow(icon: Icons.school_outlined, text: profile.education),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('About', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(profile.bio, style: const TextStyle(height: 1.4)),
        ],
        if (profile.interests.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Interests', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final interest in profile.interests) Chip(label: Text(interest))],
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
  }
}
