import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/selected_doctor_provider.dart';
import 'package:callone/widgets/consultation_card.dart';
import 'package:callone/widgets/hero_widget.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsultationSelectionScreen extends ConsumerStatefulWidget {
  const ConsultationSelectionScreen({super.key});

  @override
  ConsumerState<ConsultationSelectionScreen> createState() => _ConsultationSelectionScreenState();
}

class _ConsultationSelectionScreenState extends ConsumerState<ConsultationSelectionScreen> {
  String _selectedType = 'Video'; // Default selection

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final doctor = ref.watch(selectedDoctorProvider);

    if (doctor == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text("No doctor selected")),
      );
    }

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Green Background
          const HeroWidget(
            title: "Choose Consultation",
            showBackButton: true,
          ),
          
          // Doctor Info
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    doctor.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialization,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Consultation Options
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ConsultationCard(
                          title: "Phone Consultation",
                          price: doctor.phoneConsultationPrice,
                          duration: "(30min)",
                          isSelected: _selectedType == 'Phone',
                          onTap: () => setState(() => _selectedType = 'Phone'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ConsultationCard(
                          title: "Video Consultation",
                          price: doctor.videoConsultationPrice,
                          duration: "(30min)",
                          isSelected: _selectedType == 'Video',
                          onTap: () => setState(() => _selectedType = 'Video'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       flex: 1,
                  //       child: ConsultationCard(
                  //         title: "Chat Consultation",
                  //         price: doctor.phoneConsultationPrice,
                  //         subtitle: "(30 conversation texts)\nValid: 72 hours",
                  //         isSelected: _selectedType == 'Chat',
                  //         onTap: () => setState(() => _selectedType = 'Chat'),
                  //       ),
                  //     ),
                  //      const SizedBox(width: 16),
                  //      const Spacer(),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),

          // Proceed Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(appointmentProvider.notifier).updateAppointment(consultationType: _selectedType);
                  Navigator.pushNamed(context, '/choose_date');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.primary, // Dark green color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Proceed",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appColors.themeColor
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
