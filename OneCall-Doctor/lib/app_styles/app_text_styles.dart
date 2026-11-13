import 'package:onecall_doctor/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


final appTextStylesProvider = Provider<AppTextStyles>((ref) {
  final darkTheme = ref.watch(themeProvider);
  return AppTextStyles(darkTheme: darkTheme);
});

class AppTextStyles{
  final bool darkTheme;

  AppTextStyles({required this.darkTheme});

  TextStyle get mainHeading => TextStyle(
    color: darkTheme ? Colors.black : Colors.white,
    fontSize: 30,
  );
}