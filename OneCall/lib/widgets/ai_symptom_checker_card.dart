import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_styles/app_colors.dart';
import '../services/ai_service.dart';
import '../providers/concern_provider.dart';
import '../providers/appointment_provider.dart';

class AiSymptomCheckerCard extends ConsumerStatefulWidget {
  const AiSymptomCheckerCard({super.key});

  @override
  ConsumerState<AiSymptomCheckerCard> createState() => _AiSymptomCheckerCardState();
}

class _AiSymptomCheckerCardState extends ConsumerState<AiSymptomCheckerCard> {
  final TextEditingController _symptomController = TextEditingController();
  bool _isLoading = false;
  AiConsultResult? _result;

  final List<Map<String, String>> _quickPresets = [
    {'label': '🚨 Chest Pain', 'text': 'Severe crushing chest pain radiating to left shoulder with breathlessness'},
    {'label': '🧠 Migraine', 'text': 'Intense throbbing headache on right side with sensitivity to light and nausea'},
    {'label': '🦵 Knee Pain', 'text': 'Knee joint pain and swelling with difficulty walking after running'},
    {'label': '🤒 High Fever', 'text': 'Persistent high fever with chills and body ache for 2 days'},
  ];

  Future<void> _analyzeSymptoms() async {
    final query = _symptomController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please describe your symptoms first")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final res = await AiService().consultAI(query: query);
      setState(() {
        _result = res;
      });
    } catch (e) {
      debugPrint("Error in AI analysis: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _routeToDoctorList(SpecialtyPrediction specialty, TriagePrediction? triage) {
    // Map predicted specialty to matching concern ID if available
    String targetConcernId = 'fever';
    final lowerSpec = specialty.predictedSpecialty.toLowerCase();

    if (lowerSpec.contains('cardio') || lowerSpec.contains('pulmonary')) {
      targetConcernId = 'hypertension';
    } else if (lowerSpec.contains('neuro')) {
      targetConcernId = 'migraine';
    } else if (lowerSpec.contains('ortho') || lowerSpec.contains('chiro')) {
      targetConcernId = 'back_pain';
    } else if (lowerSpec.contains('psych') || lowerSpec.contains('mental')) {
      targetConcernId = 'anxiety';
    } else if (lowerSpec.contains('sleep')) {
      targetConcernId = 'insomnia';
    } else {
      targetConcernId = 'fever';
    }

    // Set selected concern in Riverpod
    ref.read(concernProvider.notifier).selectConcern(targetConcernId);

    // Pre-populate appointment provider with triage and patient query
    ref.read(appointmentProvider.notifier).updateAppointment(
      concernId: targetConcernId,
      triageUrgency: triage?.urgency,
      triageConfidence: triage?.confidence,
      clinicalAdvisory: triage?.clinicalAdvisory,
      detectedRedFlags: triage?.detectedRedFlags,
      predictedSpecialty: specialty.predictedSpecialty,
      patientQuery: _symptomController.text.trim(),
    );

    // Navigate to doctor list with arguments
    Navigator.pushNamed(
      context,
      '/doctor_list',
      arguments: {
        'concernId': targetConcernId,
        'specialty': specialty.predictedSpecialty,
      },
    );
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: appColors.background2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appColors.primary.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: appColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, color: appColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Symptom Assistant",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appColors.text,
                        ),
                      ),
                      Text(
                        "Specialty routing & clinical urgency triage",
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "AI Active",
                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Symptom Input Field
          TextField(
            controller: _symptomController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Describe your symptoms (e.g. sharp chest pain, migraine, knee injury)...",
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
              filled: true,
              fillColor: appColors.background.withOpacity(0.6),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: appColors.primary, width: 1.5),
              ),
            ),
            style: TextStyle(fontSize: 14, color: appColors.text),
          ),
          const SizedBox(height: 10),

          // Preset Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickPresets.map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    label: Text(preset['label']!, style: const TextStyle(fontSize: 11)),
                    backgroundColor: appColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () {
                      _symptomController.text = preset['text']!;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeSymptoms,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology, size: 20),
              label: Text(
                _isLoading ? "Evaluating Clinical AI..." : "Analyze Symptoms & Find Doctor",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),

          // Result Display
          if (_result != null && _result!.specialty != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            _buildResultCard(context, appColors, _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, AppColors appColors, AiConsultResult result) {
    final specialty = result.specialty!;
    final triage = result.triage;

    final urgency = (triage?.urgency ?? 'MEDIUM').toUpperCase();
    final isHigh = urgency == 'HIGH' || (triage?.detectedRedFlags.isNotEmpty ?? false);
    final isMed = urgency == 'MEDIUM';

    final Color urgencyColor = isHigh
        ? Colors.red
        : (isMed ? Colors.orange.shade800 : Colors.green.shade700);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh ? Colors.red.withOpacity(0.5) : appColors.primary.withOpacity(0.2),
          width: isHigh ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgency Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: urgencyColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isHigh ? Icons.warning_amber_rounded : (isMed ? Icons.info_outline : Icons.check_circle_outline),
                      color: urgencyColor,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "$urgency CLINICAL URGENCY",
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (triage != null)
                Text(
                  "Confidence: ${(triage.confidence * 100).toInt()}%",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),

          // Red flags if any
          if (triage != null && triage.detectedRedFlags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: triage.detectedRedFlags.map((flag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    "⚠️ $flag",
                    style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 10),

          // Specialty Recommendation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.medical_information_outlined, color: appColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recommended Specialty",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      specialty.predictedSpecialty,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: appColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            triage?.clinicalAdvisory ?? "Prompt evaluation recommended by a specialist.",
            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.3),
          ),

          const SizedBox(height: 12),

          // Direct Doctor List Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _routeToDoctorList(specialty, triage),
              icon: const Icon(Icons.search, size: 16),
              label: Text(
                "Find ${specialty.predictedSpecialty} Doctors",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: appColors.primary,
                side: BorderSide(color: appColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
