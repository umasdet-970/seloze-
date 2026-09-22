import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onSuperLike;
  /// Always shown (advertises the feature to Free users, standard
  /// freemium pattern) — [onRewind] fires either way; the caller decides
  /// whether that means "undo" or "show an upgrade prompt". [rewindLit]
  /// only controls this button's own visual state, not whether it's
  /// tappable — DiscoverScreen greys it out but still wants the tap to
  /// reach a Free user so it can explain why.
  final VoidCallback onRewind;
  final bool rewindLit;

  const ActionButtons({
    super.key,
    required this.onPass,
    required this.onLike,
    required this.onSuperLike,
    required this.onRewind,
    this.rewindLit = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: Icons.replay,
          color: rewindLit ? AppColors.superLike : Colors.grey,
          size: 44,
          iconSize: 20,
          onTap: onRewind,
        ),
        _CircleButton(
          icon: Icons.close,
          color: AppColors.pass,
          size: 56,
          iconSize: 26,
          onTap: onPass,
        ),
        _CircleButton(
          icon: Icons.favorite,
          color: AppColors.like,
          size: 68,
          iconSize: 30,
          filled: true,
          onTap: onLike,
        ),
        _CircleButton(
          icon: Icons.star,
          color: AppColors.superLike,
          size: 56,
          iconSize: 24,
          onTap: onSuperLike,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool filled;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: filled ? color : Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: filled ? Colors.white : color, size: iconSize),
        ),
      ),
    );
  }
}
