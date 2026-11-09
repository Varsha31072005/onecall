import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_styles/app_colors.dart';

class AppAppBar extends ConsumerWidget implements PreferredSizeWidget{
  final String name;
  final List<Widget>? actions;
  final Widget? leading;
  
  const AppAppBar( {
    super.key,
    required this.name,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    return AppBar(
      title: Text(name),
      centerTitle: true,
      elevation: 0,
      backgroundColor: appColors.secondary,
      foregroundColor: Colors.black,
      actions: actions,
      leading: leading,
    );
  }
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
