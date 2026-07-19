import 'package:flutter/material.dart';
import '../main.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int count;
  final double starSize;
  final bool showCount;

  const StarRating({
    super.key,
    required this.rating,
    this.count = 0,
    this.starSize = 12,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          IconData icon;
          final val = rating - i;
          if (val >= 1) {
            icon = Icons.star;
          } else if (val >= 0.5) {
            icon = Icons.star_half;
          } else {
            icon = Icons.star_border;
          }
          return Icon(icon,
              size: starSize,
              color: val > 0 ? AppColors.secondary : cs.outlineVariant);
        }),
        if (showCount && count > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: starSize * 0.85,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final int initialRating;
  final ValueChanged<int> onChanged;
  final double starSize;

  const InteractiveStarRating({
    super.key,
    this.initialRating = 0,
    required this.onChanged,
    this.starSize = 36,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < _selected;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = i + 1);
            widget.onChanged(i + 1);
          },
          child: AnimatedScale(
            scale: filled ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: widget.starSize,
              color: filled ? AppColors.secondary : AppColors.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }
}
