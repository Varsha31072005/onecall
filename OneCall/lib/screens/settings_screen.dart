import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final appColors = ref.watch(appColorsProvider);

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: const AppAppBar(name: 'Settings'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: appColors.background2,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.light_mode,
                        color: appColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Light Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: appColors.text,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: isDark,
                    activeColor: appColors.primary,
                    onChanged: (value) {
                      // 4. Update the provider
                      ref.read(themeProvider.notifier).changeTheme();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
