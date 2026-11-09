import 'package:callone/app_styles/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsultationCard extends ConsumerWidget {
  final String title;
  final double price;
  final String duration;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const ConsultationCard({
    super.key,
    required this.title,
    required this.price,
    this.duration = "",
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: appColors.background2,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: appColors.primary, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: appColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            Column(
              children: [
                Text(
                  "₹ ${price.toInt()}${duration.isNotEmpty ? '/min' : ''}",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: appColors.text,
                  ),
                ),
                if (duration.isNotEmpty)
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? appColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? appColors.primary : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
