import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/data/models/appointment.dart';
import 'package:callone/providers/selected_doctor_provider.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/booking_service.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/services/user_service.dart';
import 'package:callone/providers/last_payment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/app_bar.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    final doctor = ref.watch(selectedDoctorProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final appointment = ref.watch(appointmentProvider); // Watch appointment for UI updates

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppAppBar(
        name: 'Payment',
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appColors.themeColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Main Info Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                    decoration: BoxDecoration(
                      color: appColors.background2,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        // Doctor Profile Image with Checkmark
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: doctor != null
                                    ? Image.network(
                                        doctor.imageUrl,
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 110,
                                          height: 110,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.person, size: 55),
                                        ),
                                      )
                                    : Container(
                                        width: 110,
                                        height: 110,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.person, size: 55),
                                      ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 12),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.check_circle, 
                                  color: Color(0xff67B26F), 
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        
                        // Detail Rows
                        _buildDetailRow("Expert", doctor?.name ?? "Dr. Prem", appColors),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          "Appointment Date", 
                          appointment?.date != null 
                              ? "${appointment!.date.day}/${appointment.date.month}/${appointment.date.year}" 
                              : "---", 
                          appColors
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow("Appointment Time", appointment?.time ?? "---", appColors),
                        const SizedBox(height: 16),
                        _buildDetailRow("Consultation Type", appointment?.consultationType.isNotEmpty == true ? appointment!.consultationType : "Video Consultation", appColors),
                        const SizedBox(height: 16),
                        
                        if (user != null)
                          ref.watch(userProfileProvider(user.uid)).when(
                                data: (snapshot) {
                                  final data = snapshot.data() as Map<String, dynamic>? ?? {};
                                  final balance = data['walletBalance'] ?? 0;
                                  return _buildDetailRow("Current Wallet Balance", "₹ ${balance.toInt()}", appColors);
                                },
                                loading: () => _buildDetailRow("Current Wallet Balance", "₹ ---", appColors),
                                error: (_, __) => _buildDetailRow("Current Wallet Balance", "Error", appColors),
                              ),
                        const SizedBox(height: 16),
                        _buildDetailRow("Consultation Fee", "₹ ${appointment?.consultationType == 'Video' ? doctor?.videoConsultationPrice.toInt() : doctor?.phoneConsultationPrice.toInt()}", appColors),
                      ],
                    ),
                  ),

                  // AI CLINICAL ASSESSMENT CARD (Before Payment)
                  _buildAiAssessmentCard(appointment, appColors, context),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Bottom Button: Make Payment
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in")));
                    return;
                  }

                  // High urgency clinical safety check before payment
                  final isHigh = (appointment?.triageUrgency?.toUpperCase() == 'HIGH') ||
                      (appointment?.detectedRedFlags != null && appointment!.detectedRedFlags!.isNotEmpty);
                  if (isHigh) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "High Risk Advisory",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          "Our clinical AI flagged high urgency symptoms. Please consult a doctor physically at an emergency clinic if needed.\n\nDo you still wish to proceed with this telemedicine consultation?",
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Acknowledge & Pay"),
                          ),
                        ],
                      ),
                    );

                    if (proceed != true) return;
                  }
                  
                  // Update appointment with missing IDs and emails
                  if (doctor != null) {
                    ref.read(appointmentProvider.notifier).updateAppointment(
                      patientId: user.uid,
                      doctorId: doctor.id,
                      userEmail: user.email ?? '',
                      doctorEmail: doctor.email,
                    );
                  }

                  // Re-read updated appointment
                  final updatedAppointment = ref.read(appointmentProvider);

                  if (updatedAppointment != null) {
                    try {
                      // Validate Wallet Balance
                      final userDoc = await ref.read(userServiceProvider).getUserProfile(user.uid);
                      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
                      final double balance = (userData['walletBalance'] ?? 0).toDouble();
                      final double price = appointment!.consultationType == 'Video'
                          ? doctor!.videoConsultationPrice
                          : doctor!.phoneConsultationPrice;

                      if (balance < price) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                               content: Text("Insufficient balance. Required: ₹${price.toInt()}, Available: ₹${balance.toInt()}"),
                               backgroundColor: Colors.red,
                             )
                           );
                         }
                         return;
                      }

                      // Show loading indicator if needed
                      await BookingService().bookAppointment(updatedAppointment, price);
                      
                      // Save paid amount for success screen
                      ref.read(lastPaymentProvider.notifier).state = price;

                      if (context.mounted) {
                         Navigator.pushNamed(context, '/payment_success');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking failed: $e")));
                      }
                    }
                  } else {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No appointment details found")));
                     }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text("Make Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssessmentCard(AppointmentModel? appointment, AppColors appColors, BuildContext context) {
    if (appointment == null || appointment.triageUrgency == null) {
      return const SizedBox.shrink();
    }

    final urgency = appointment.triageUrgency!.toUpperCase();
    final redFlags = appointment.detectedRedFlags ?? [];
    final isHigh = urgency == 'HIGH' || redFlags.isNotEmpty;
    final isMedium = urgency == 'MEDIUM';
    final specialty = appointment.predictedSpecialty?.isNotEmpty == true
        ? appointment.predictedSpecialty!
        : 'General Medicine';
    final advisory = appointment.clinicalAdvisory?.isNotEmpty == true
        ? appointment.clinicalAdvisory!
        : (isHigh
            ? 'Immediate physical clinical examination recommended.'
            : 'Virtual consultation suitable for current symptoms.');

    if (isHigh) {
      // HIGH CLINICAL URGENCY: Prominent Flag to consult doctor physically (High Risk)
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F0), // Soft clinical warning background
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFA39E), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Clinical AI Assessment",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "HIGH RISK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mandatory User Requirement: High Risk Physical Doctor Flag
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade300, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.emergency_rounded, color: Colors.red.shade700, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Please consult to doctor physically, it is high risk",
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Your symptoms indicate potential acute conditions requiring in-person physical clinical evaluation.",
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (redFlags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "Detected Red Flags:",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 4),
              ...redFlags.map(
                (flag) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• ", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          flag,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            // Specialty and Advisory
            Row(
              children: [
                Icon(Icons.medical_services_outlined, size: 15, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Matched Specialty: $specialty",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              advisory,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // NORMAL OR MEDIUM: Show the result alone without high risk warning flag
    final badgeColor = isMedium ? Colors.amber.shade800 : const Color(0xFF389E0D);
    final badgeBg = isMedium ? Colors.amber.shade100 : const Color(0xFFF6FFED);
    final borderColor = isMedium ? const Color(0xFFFFE58F) : const Color(0xFFB7EB8F);
    final cardBg = isMedium ? const Color(0xFFFFFBE6) : const Color(0xFFFAFDFA);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isMedium ? Colors.amber.shade100 : const Color(0xFFD9F7BE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMedium ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                  color: badgeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "AI Clinical Assessment",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: appColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  isMedium ? "MEDIUM URGENCY" : "NORMAL URGENCY",
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Result details alone: Matched specialty and advisory
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medical_services_outlined, size: 16, color: appColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      "Predicted Specialty:",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        specialty,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: appColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  advisory,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColors appColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: appColors.text, // Adjust based on theme logic
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
