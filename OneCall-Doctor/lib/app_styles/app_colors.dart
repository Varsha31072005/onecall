import 'package:onecall_doctor/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appColorsProvider = Provider<AppColors>((ref) {
  final darkTheme = ref.watch(themeProvider);
  return AppColors(darkTheme: darkTheme);
});


class AppColors {
  final bool darkTheme;

  AppColors({required this.darkTheme});

  Color get primary => const Color(0xff3A643B);
  Color get secondary => darkTheme? const Color(0xff718D6A) : const Color(0xffA5D6A7);
  Color get colortint => darkTheme? const Color(0xffEAF2EA) : const Color(0xff2C3E30);
  Color get background => darkTheme? const Color(0xffFAFAFA) : const Color(0xff121212);
  Color get background2 => darkTheme? const Color(0xffE0E8E2) : const Color(0xff1E1E1E);
  Color get text => darkTheme? Colors.black : Colors.white;
  Color get themeColor => darkTheme? Colors.white : Colors.black;
}
