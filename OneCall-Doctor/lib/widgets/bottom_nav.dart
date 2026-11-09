import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_styles/app_colors.dart';

class BottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    return BottomAppBar(
      height: 70,
      shape: const CircularNotchedRectangle(), // Creates the smooth cutout
      notchMargin: 8.0, // Space between FAB and the bar
      color: appColors.primary.withOpacity(0.80),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,

      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: appColors.primary,
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
        currentIndex: currentIndex,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: "Appointments",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_2_outlined),
            label: "Profile",
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.settings_outlined),
          //   label: "Settings",
          // ),
        ],
      ),
    );
  }
}
