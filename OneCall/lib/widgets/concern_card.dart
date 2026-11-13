import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_styles/app_colors.dart';
import '../data/models/concern.dart';

class ConcernCard extends ConsumerWidget {
  final Concern concern;
  final bool isSelected;
  final VoidCallback onTap;

  const ConcernCard({
    super.key,
    required this.concern,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? appColors.primary : Colors.transparent,
                width: 2,
              ),
              color: appColors.background2,
            ),
            child: Icon(concern.icon as IconData?, size: isSelected ? 32 : 30, color: appColors.primary),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              concern.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
                color: appColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}