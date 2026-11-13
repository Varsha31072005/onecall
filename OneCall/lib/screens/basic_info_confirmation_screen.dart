import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/screens/profile_screen.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/user_service.dart';
import 'package:callone/widgets/hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BasicInfoConfirmationScreen extends ConsumerWidget {
  const BasicInfoConfirmationScreen({super.key});

  String _severityText(double? val) {
    if (val == null) return 'Mild';
    if (val <= 0.5) return 'Mild';
    if (val <= 1.5) return 'Moderate';
    return 'Severe';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final appointment = ref.watch(appointmentProvider);

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeroWidget(title: "Basic Information", showBackButton: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                        Icon(Icons.person_pin_circle_outlined, size: 16, color: appColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Step 2 of 3: Patient Profile Confirmation",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: appColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Concern Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: appColors.background2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: appColors.primary.withOpacity(0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medical_information_outlined, color: appColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Recorded Concern & Symptoms",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: appColors.text,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Concern:", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            Text(
                              appointment?.concernId.isNotEmpty == true ? appointment!.concernId : "General",
                              style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Severity:", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            Text(
                              _severityText(appointment?.severity),
                              style: TextStyle(color: appColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Duration:", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            Text(
                              appointment?.duration.isNotEmpty == true ? appointment!.duration : "Not specified",
                              style: TextStyle(color: appColors.text, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        if (appointment?.patientQuery != null && appointment!.patientQuery!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: appColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "\"${appointment.patientQuery}\"",
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: appColors.text),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Patient Demographic Info",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appColors.text),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                        icon: Icon(Icons.edit_outlined, color: appColors.primary, size: 16),
                        label: Text("Edit", style: TextStyle(color: appColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  Text(
                    "Patient age and gender are factored directly into the AI clinical triage urgency calculation.",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  if (user != null)
                    ref.watch(userProfileProvider(user.uid)).when(
                      data: (snapshot) {
                        final data = snapshot.data() as Map<String, dynamic>? ?? {};
                        final gender = data['gender']?.toString() ?? 'Not specified';
                        final age = data['age']?.toString() ?? '--';
                        final height = data['height']?.toString() ?? '--';
                        final weight = data['weight']?.toString() ?? '--';

                        return Column(
                          children: [
                            _buildInfoField("Gender", gender, appColors, context),
                            const SizedBox(height: 12),
                            _buildInfoField("Age", "$age years", appColors, context),
                            const SizedBox(height: 12),
                            _buildInfoField("Height", "$height cms", appColors, context),
                            const SizedBox(height: 12),
                            _buildInfoField("Weight", "$weight kg", appColors, context),
                          ],
                        );
                      },
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      )),
                      error: (err, _) => Column(
                        children: [
                          _buildInfoField("Gender", "Unknown", appColors, context),
                          const SizedBox(height: 12),
                          _buildInfoField("Age", "30 years (Default)", appColors, context),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildInfoField("Gender", "General", appColors, context),
                        const SizedBox(height: 12),
                        _buildInfoField("Age", "30 years", appColors, context),
                      ],
                    ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          
          // Proceed to AI Clinical Assessment Page
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/ai_triage_result');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Run AI Clinical Assessment",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value, AppColors appColors, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: appColors.background2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: appColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
