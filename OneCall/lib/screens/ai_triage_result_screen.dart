import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/services/ai_service.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/user_service.dart';
import 'package:callone/widgets/hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiTriageResultScreen extends ConsumerStatefulWidget {
  const AiTriageResultScreen({super.key});

  @override
  ConsumerState<AiTriageResultScreen> createState() => _AiTriageResultScreenState();
}

class _AiTriageResultScreenState extends ConsumerState<AiTriageResultScreen> {
  bool _isLoading = true;
  AiConsultResult? _consultResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAiAssessment();
    });
  }

  Future<void> _runAiAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appointment = ref.read(appointmentProvider);
    final user = ref.read(authServiceProvider).currentUser;

    double? patientAge;
    String? patientGender;

    if (user != null) {
      try {
        final doc = await UserService().getUserProfile(user.uid);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            patientAge = double.tryParse(data['age']?.toString() ?? '');
            patientGender = data['gender']?.toString();
          }
        }
      } catch (e) {
        debugPrint("Error fetching profile for AI assessment: $e");
      }
    }

    final query = (appointment?.patientQuery != null && appointment!.patientQuery!.isNotEmpty)
        ? appointment.patientQuery!
        : (appointment?.concernId ?? 'General consultation');

    final severityLabel = appointment?.severity != null
        ? (appointment!.severity <= 0.5
            ? 'mild'
            : (appointment.severity <= 1.5 ? 'moderate' : 'severe'))
        : 'moderate';

    try {
      final result = await AiService().consultAI(
        query: query,
        symptoms: appointment?.patientQuery ?? query,
        duration: appointment?.duration,
        severity: severityLabel,
        age: patientAge ?? 30.0,
        gender: patientGender ?? 'unknown',
      );

      final triage = result.triage;
      final specialty = result.specialty;

      // Update Riverpod appointment state with AI predictions
      ref.read(appointmentProvider.notifier).updateAppointment(
        triageUrgency: triage?.urgency ?? 'LOW',
        triageConfidence: triage?.confidence ?? 0.8,
        clinicalAdvisory: triage?.clinicalAdvisory ?? 'Routine care appropriate.',
        detectedRedFlags: triage?.detectedRedFlags ?? [],
        predictedSpecialty: specialty?.predictedSpecialty ?? 'General Medicine',
      );

      setState(() {
        _consultResult = result;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("AI consultation exception: $e");
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showEmergencyDialog(BuildContext context, AppColors appColors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              "Emergency Services",
              style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Please call one of the national emergency helpline numbers immediately or visit the nearest hospital emergency room:",
              style: TextStyle(color: appColors.text, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildEmergencyPhoneRow("National Emergency", "112", appColors),
            const SizedBox(height: 8),
            _buildEmergencyPhoneRow("Ambulance Services", "108", appColors),
            const SizedBox(height: 8),
            _buildEmergencyPhoneRow("Medical Helpline", "102 / 911", appColors),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: TextStyle(color: appColors.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Exit to Home"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyPhoneRow(String label, String number, AppColors appColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: appColors.text, fontSize: 13)),
          Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final appointment = ref.watch(appointmentProvider);

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeroWidget(title: "AI Clinical Assessment", showBackButton: true),
          Expanded(
            child: _isLoading
                ? _buildLoadingState(appColors)
                : _buildAssessmentContent(appColors, appointment),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(AppColors appColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  color: appColors.primary,
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "Evaluating Clinical Data...",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: appColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Running Model 1 (Clinical Urgency Triage)\nRunning Model 2 (Medical Specialty Routing)",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentContent(AppColors appColors, dynamic appointment) {
    final triage = _consultResult?.triage;
    final specialty = _consultResult?.specialty;

    if (_consultResult == null && _errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                "Unable to Complete Assessment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _runAiAssessment,
                style: ElevatedButton.styleFrom(backgroundColor: appColors.primary, foregroundColor: Colors.white),
                child: const Text("Retry Analysis"),
              ),
            ],
          ),
        ),
      );
    }

    final isHighUrgency = triage?.isHighUrgency ?? false;
    final isMediumUrgency = (triage?.isMediumUrgency ?? false) && !isHighUrgency;
    final isNormal = !isHighUrgency && !isMediumUrgency;
    final canProceedToDoctor = !isHighUrgency;

    final predictedSpecialty = specialty?.predictedSpecialty ?? 'General Medicine';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: appColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: appColors.primary),
                const SizedBox(width: 6),
                Text(
                  "Step 3 of 3: Dual-Model Clinical Evaluation",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: appColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // CLINICAL ASSESSMENT (URGENCY TRIAGE)
          // ==========================================
          if (isNormal) ...[
            // NORMAL / LOW URGENCY - SAFE FOR TELECONSULTATION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xfff0fdf4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff86efac), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xff22c55e),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Clinical Assessment: Normal",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff15803d),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Low Urgency • Safe for Teleconsultation",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xffbbf7d0)),
                  const SizedBox(height: 8),
                  Text(
                    triage?.clinicalAdvisory ??
                        "Routine outpatient care or self-monitoring is appropriate. Seek immediate care if symptoms unexpectedly worsen.",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xff166534),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isMediumUrgency) ...[
            // MEDIUM URGENCY - SAFE TO PROCEED WITH DOCTOR CONSULTATION & PAYMENT
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xfffffbeb),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xfffcd34d), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xfff59e0b),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Clinical Assessment: Medium Urgency",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffb45309),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Prompt Consultation Recommended • Safe to Proceed",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xfffde68a)),
                  const SizedBox(height: 8),
                  Text(
                    triage?.clinicalAdvisory ??
                        "Prompt medical evaluation recommended. You may proceed to choose a specialist doctor for consultation.",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xff92400e),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // HIGH URGENCY ONLY - GO TO HOSPITAL IMMEDIATELY!
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xfffff1f2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xfffda4af), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xffe11d48),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Go to Hospital",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xffbe123c),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Clinical Urgency: High (Emergency)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff9f1239),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xfffecdd3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "⚠️ The app is not suitable for your condition.",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff9f1239),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Based on clinical triage safety protocols, high urgency conditions require direct, in-person clinical evaluation or emergency hospitalization. Virtual teleconsultations are not safe or equipped to handle this level of acuity.",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xff4c0519),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (triage != null && triage.detectedRedFlags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      "Detected Clinical Red Flags:",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffbe123c),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...triage.detectedRedFlags.map((flag) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle, size: 8, color: Color(0xffe11d48)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  flag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff881337),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    "Advisory: ${triage?.clinicalAdvisory}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xff9f1239),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ==========================================
          // PREDICTED SPECIALTY (MODEL 2)
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appColors.background2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: appColors.primary.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology_outlined, color: appColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "Predicted Specialty",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: appColors.text,
                          ),
                        ),
                      ],
                    ),
                    if (specialty != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: appColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${(specialty.confidence * 100).toInt()}% match",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: appColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  predictedSpecialty,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: appColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  specialty?.secondSpecialty != null
                      ? "Alternative: ${specialty!.secondSpecialty}"
                      : "Identified based on clinical symptom narrative analysis.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ==========================================
          // WORKFLOW ACTIONS
          // ==========================================
          if (canProceedToDoctor) ...[
            // NORMAL & MEDIUM URGENCY: Proceed to Select Doctor based on predicted specialty
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/doctor_list',
                    arguments: {
                      'specialty': predictedSpecialty,
                      'concernId': appointment?.concernId,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Select Doctor ($predictedSpecialty)",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ] else ...[
            // HIGH URGENCY ONLY: Show Go to Hospital & Emergency Helpline
            // NO OPTION TO BOOK THE DOCTOR!
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _showEmergencyDialog(context, appColors),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffe11d48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.phone_in_talk_rounded),
                label: const Text(
                  "Call Emergency Services (112 / 108)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: appColors.text,
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Exit to Home",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
