import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// Display-only star rating widget (1–10 scale shown as 1–5 stars)
class StarRating extends StatelessWidget {
  final int? rating;
  final double itemSize;
  final bool showNumber;

  const StarRating({
    super.key,
    required this.rating,
    this.itemSize = 24,
    this.showNumber = true,
  });

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Text(
        'Не оценено',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating! / 2.0,
          itemBuilder: (context, _) => const Icon(
            Icons.star_rounded,
            color: Color(0xFFFFCA28),
          ),
          itemCount: 5,
          itemSize: itemSize,
          unratedColor: Colors.white12,
        ),
        if (showNumber) ...[
          const SizedBox(width: 8),
          Text(
            '$rating/10',
            style: TextStyle(
              fontSize: itemSize * 0.65,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFCA28),
            ),
          ),
        ],
      ],
    );
  }
}

/// Interactive star rating widget
class InteractiveStarRating extends StatelessWidget {
  final int? initialRating;
  final ValueChanged<int> onRatingChanged;
  final double itemSize;

  const InteractiveStarRating({
    super.key,
    this.initialRating,
    required this.onRatingChanged,
    this.itemSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: (initialRating ?? 0) / 2.0,
      minRating: 0.5,
      maxRating: 5,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: itemSize,
      itemBuilder: (context, _) => const Icon(
        Icons.star_rounded,
        color: Color(0xFFFFCA28),
      ),
      unratedColor: Colors.white12,
      onRatingUpdate: (v) => onRatingChanged((v * 2).round()),
    );
  }
}
