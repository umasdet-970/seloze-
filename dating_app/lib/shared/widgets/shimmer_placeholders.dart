import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton-loading building blocks (spec section 21). Wraps
/// `shimmer` so every screen gets the same shimmer tuning instead of
/// each hand-rolling its own base/highlight colors.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300,
      highlightColor: isDark ? Colors.white.withOpacity(0.14) : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius),
      ),
    );
  }
}

/// A full-bleed rounded-card skeleton, matching ProfileCard's shape —
/// used while the Discover feed's first batch loads.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(28)));
  }
}

/// A row-shaped skeleton matching a typical avatar + two-line list tile —
/// used for Matches/Chat/Notifications lists while data loads.
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const ShimmerBox(width: 56, height: 56, borderRadius: BorderRadius.all(Radius.circular(28))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 140, height: 14),
                const SizedBox(height: 8),
                ShimmerBox(width: MediaQuery.of(context).size.width * 0.4, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A square tile skeleton — used for the Likes grid while data loads.
class ShimmerGridTile extends StatelessWidget {
  const ShimmerGridTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(18)));
  }
}
