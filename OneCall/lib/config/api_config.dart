import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Base URL of the OneCall AI Microservice.
  /// To deploy remotely, simply update [customBaseUrl] or set it at runtime.
  static String? customBaseUrl;

  /// Default port used by the local unified backend
  static const int port = 5000;

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }

    if (kIsWeb) {
      return 'http://localhost:$port';
    }

    // Android emulator cannot access 127.0.0.1 directly; 10.0.2.2 routes to the host machine.
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$port';
    }

    // iOS simulator, desktop (Windows, macOS, Linux)
    return 'http://localhost:$port';
  }

  // API Endpoints
  static String get healthUrl => '$baseUrl/health';
  static String get triageUrl => '$baseUrl/api/triage';
  static String get predictSpecialtyUrl => '$baseUrl/api/predict-specialty';
  static String get consultUrl => '$baseUrl/api/consult';
}
