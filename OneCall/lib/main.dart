import 'dart:io';

import 'package:callone/firebase_options.dart';
import 'package:callone/screens/choose_date_screen.dart';
import 'package:callone/screens/choose_time_slot_screen.dart';
import 'package:callone/screens/ai_triage_result_screen.dart';
import 'package:callone/screens/payment_screen.dart';
import 'package:callone/screens/payment_success_screen.dart';
import 'package:callone/screens/consultation_selection_screen.dart';
import 'package:callone/screens/doctor_list_screen.dart';
import 'package:callone/screens/your_concern_screen.dart';
import 'package:callone/screens/auth/login_screen.dart';
import 'package:callone/screens/auth/register_screen.dart';
import 'package:callone/screens/basic_info_confirmation_screen.dart';
import 'package:callone/widget_tree.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';

import 'app_styles/app_colors.dart';

import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  /// 1.2.1: Set navigator key to ZegoUIKitPrebuiltCallInvitationService
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  // Initialize Notification Service
  await NotificationService().init();

  runApp(
    ProviderScope(
      child: const MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final colorProvider = ref.watch(appColorsProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CallOne',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: colorProvider.primary),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/' : (context) => const WidgetTree(),
        '/login' : (context) => const LoginScreen(),
        '/register' : (context) => const RegisterScreen(),
        '/doctor_list' : (context) => const DoctorListScreen(),
        '/consultation_selection' : (context) => const ConsultationSelectionScreen(),
        '/choose_date' : (context) => const ChooseDateScreen(),
        '/choose_time_slot' : (context) => const ChooseTimeSlotScreen(),
        '/your_concern' : (context) => const YourConcernScreen(),
        '/basic_info_confirmation' : (context) => const BasicInfoConfirmationScreen(),
        '/ai_triage_result' : (context) => const AiTriageResultScreen(),
        '/payment' : (context) => const PaymentScreen(),
        '/payment_success' : (context) => const PaymentSuccessScreen(),
      },
    );
  }
}
