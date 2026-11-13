import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SpecialtyPrediction {
  final String predictedSpecialty;
  final double confidence;
  final String? secondSpecialty;
  final double secondProbability;
  final String confidenceLevel;
  final String? marginFlag;
  final Map<String, double> topProbabilities;

  SpecialtyPrediction({
    required this.predictedSpecialty,
    required this.confidence,
    this.secondSpecialty,
    this.secondProbability = 0.0,
    required this.confidenceLevel,
    this.marginFlag,
    this.topProbabilities = const {},
  });

  factory SpecialtyPrediction.fromJson(Map<String, dynamic> json) {
    final topMap = <String, double>{};
    if (json['top_probabilities'] is Map) {
      json['top_probabilities'].forEach((k, v) {
        topMap[k.toString()] = (v as num).toDouble();
      });
    }

    return SpecialtyPrediction(
      predictedSpecialty: json['predicted_specialty'] ?? 'General Medicine',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      secondSpecialty: json['second_specialty'],
      secondProbability: (json['second_probability'] ?? 0.0).toDouble(),
      confidenceLevel: json['confidence_level'] ?? 'Moderate',
      marginFlag: json['margin_flag'],
      topProbabilities: topMap,
    );
  }
}

class TriagePrediction {
  final String urgency; // 'HIGH', 'MEDIUM', 'LOW'
  final String urgencyLevel; // 'high', 'medium', 'low'
  final double confidence;
  final Map<String, double> probabilities;
  final String clinicalAdvisory;
  final List<String> detectedRedFlags;
  final String activeModel;

  TriagePrediction({
    required this.urgency,
    required this.urgencyLevel,
    required this.confidence,
    required this.probabilities,
    required this.clinicalAdvisory,
    required this.detectedRedFlags,
    required this.activeModel,
  });

  bool get isNormal => urgency.toUpperCase() == 'LOW' || urgencyLevel == 'low';
  bool get isMediumUrgency => urgency.toUpperCase() == 'MEDIUM' || urgencyLevel == 'medium';
  bool get isHighUrgency => urgency.toUpperCase() == 'HIGH' || urgencyLevel == 'high' || detectedRedFlags.isNotEmpty;
  bool get requiresHospital => isHighUrgency; // Only HIGH requires emergency hospital diversion
  bool get canProceedToDoctor => !isHighUrgency; // Both LOW and MEDIUM can proceed with consultation & payment

  factory TriagePrediction.fromJson(Map<String, dynamic> json) {
    final probs = <String, double>{};
    if (json['probabilities'] is Map) {
      json['probabilities'].forEach((k, v) {
        probs[k.toString()] = (v as num).toDouble();
      });
    }

    final flags = <String>[];
    if (json['detected_red_flags'] is List) {
      for (final f in json['detected_red_flags']) {
        flags.add(f.toString());
      }
    }

    return TriagePrediction(
      urgency: (json['urgency'] ?? 'MEDIUM').toString().toUpperCase(),
      urgencyLevel: (json['urgency_level'] ?? 'medium').toString().toLowerCase(),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      probabilities: probs,
      clinicalAdvisory: json['clinical_advisory'] ?? 'Consult a healthcare professional.',
      detectedRedFlags: flags,
      activeModel: json['active_model'] ?? 'OneCall Triage Engine',
    );
  }
}

class AiConsultResult {
  final SpecialtyPrediction? specialty;
  final TriagePrediction? triage;
  final bool isSuccess;
  final String? errorMessage;

  AiConsultResult({
    this.specialty,
    this.triage,
    this.isSuccess = true,
    this.errorMessage,
  });
}

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  /// Runs both Model 1 (Clinical Urgency Triage) and Model 2 (Specialty Prediction)
  Future<AiConsultResult> consultAI({
    required String query,
    String? symptoms,
    String? duration,
    double? age,
    String? gender,
    String? comorbidities,
    String? severity,
  }) async {
    final url = Uri.parse(ApiConfig.consultUrl);
    final payload = {
      'query': query,
      'symptoms': symptoms ?? '',
      'duration': duration ?? '',
      'age': age,
      'gender': gender ?? '',
      'comorbidities': comorbidities ?? '',
      'severity': severity ?? '',
    };

    try {
      debugPrint("OneCall AI: Calling $url with payload $payload");
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final specialty = data['specialty'] != null
            ? SpecialtyPrediction.fromJson(data['specialty'])
            : null;
        final triage = data['triage'] != null
            ? TriagePrediction.fromJson(data['triage'])
            : null;

        return AiConsultResult(
          specialty: specialty,
          triage: triage,
          isSuccess: true,
        );
      } else {
        debugPrint("OneCall AI Server returned status: ${response.statusCode}");
        return _fallbackConsult(query, symptoms, duration, age);
      }
    } catch (e) {
      debugPrint("OneCall AI network exception: $e. Using local safety fallback.");
      return _fallbackConsult(query, symptoms, duration, age);
    }
  }

  /// Evaluates Model 1 (Clinical Urgency Triage)
  Future<TriagePrediction> evaluateTriage({
    required String query,
    String? symptoms,
    String? duration,
    double? age,
    String? gender,
    String? comorbidities,
  }) async {
    final url = Uri.parse(ApiConfig.triageUrl);
    final payload = {
      'patient_query': query,
      'symptoms': symptoms ?? '',
      'duration': duration ?? '',
      'age': age,
      'gender': gender ?? '',
      'comorbidities': comorbidities ?? '',
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TriagePrediction.fromJson(data);
      }
    } catch (e) {
      debugPrint("OneCall Triage API error: $e");
    }

    // Local clinical safety fallback if offline
    return _localTriageFallback(query);
  }

  /// Evaluates Model 2 (Medical Specialty Prediction)
  Future<SpecialtyPrediction> predictSpecialty(String transcription) async {
    final url = Uri.parse(ApiConfig.predictSpecialtyUrl);
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'transcription': transcription}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SpecialtyPrediction.fromJson(data);
      }
    } catch (e) {
      debugPrint("OneCall Specialty API error: $e");
    }

    return _localSpecialtyFallback(transcription);
  }

  // --- Local Offline Safety Fallbacks ---
  AiConsultResult _fallbackConsult(String query, String? symptoms, String? duration, double? age) {
    final combined = "$query ${symptoms ?? ''}".toLowerCase();
    final triage = _localTriageFallback(combined);
    final specialty = _localSpecialtyFallback(combined);

    return AiConsultResult(
      specialty: specialty,
      triage: triage,
      isSuccess: true,
      errorMessage: "Processed via local safety fallback.",
    );
  }

  TriagePrediction _localTriageFallback(String text) {
    final lower = text.toLowerCase();
    final redFlags = <String>[];

    if (lower.contains('chest pain') || lower.contains('pressure in chest') || lower.contains('radiating')) {
      redFlags.add('Severe chest pain / pressure');
    }
    if (lower.contains('cannot breathe') || lower.contains("can't breathe") || lower.contains('shortness of breath')) {
      redFlags.add('Acute shortness of breath');
    }
    if (lower.contains('stroke') || lower.contains('numbness') || lower.contains('slurred speech')) {
      redFlags.add('Signs of stroke');
    }

    final isHigh = redFlags.isNotEmpty || lower.contains('severe') || lower.contains('crushing');
    final isMed = !isHigh && (lower.contains('fever') || lower.contains('pain') || lower.contains('vomit'));

    final urgency = isHigh ? 'HIGH' : (isMed ? 'MEDIUM' : 'LOW');
    final advisory = isHigh
        ? 'Immediate medical attention / emergency evaluation required. Do not delay care.'
        : (isMed
            ? 'Prompt medical evaluation recommended. Contact outpatient clinic or urgent care.'
            : 'Routine care or self-monitoring appropriate.');

    return TriagePrediction(
      urgency: urgency,
      urgencyLevel: urgency.toLowerCase(),
      confidence: 0.85,
      probabilities: {'low': isHigh ? 0.05 : 0.6, 'medium': isMed ? 0.7 : 0.2, 'high': isHigh ? 0.85 : 0.1},
      clinicalAdvisory: advisory,
      detectedRedFlags: redFlags,
      activeModel: 'Clinical Safety Heuristic',
    );
  }

  SpecialtyPrediction _localSpecialtyFallback(String text) {
    final lower = text.toLowerCase();
    String spec = 'General Medicine';

    if (lower.contains('heart') || lower.contains('chest') || lower.contains('breath') || lower.contains('cardio') || lower.contains('pressure')) {
      spec = 'Cardiovascular / Pulmonary';
    } else if (lower.contains('headache') || lower.contains('migraine') || lower.contains('dizzy') || lower.contains('nerve') || lower.contains('brain')) {
      spec = 'Neurology';
    } else if (lower.contains('bone') || lower.contains('fracture') || lower.contains('knee') || lower.contains('joint') || lower.contains('spine') || lower.contains('back')) {
      spec = 'Orthopedic';
    } else if (lower.contains('depress') || lower.contains('anxiety') || lower.contains('mental') || lower.contains('sleep') || lower.contains('stress')) {
      spec = 'Psychiatry / Psychology';
    } else if (lower.contains('eye') || lower.contains('vision')) {
      spec = 'Ophthalmology';
    } else if (lower.contains('ear') || lower.contains('nose') || lower.contains('throat')) {
      spec = 'ENT - Otolaryngology';
    }

    return SpecialtyPrediction(
      predictedSpecialty: spec,
      confidence: 0.75,
      confidenceLevel: 'Moderate',
      topProbabilities: {spec: 0.75, 'General Medicine': 0.15},
    );
  }
}
