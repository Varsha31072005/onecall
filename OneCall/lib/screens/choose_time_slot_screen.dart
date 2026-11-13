import 'package:callone/app_styles/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/providers/booked_slots_provider.dart';
import 'package:callone/providers/doctors_provider.dart';
import 'package:callone/providers/selected_doctor_provider.dart';
import 'package:callone/screens/payment_screen.dart';
import 'package:callone/widgets/hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChooseTimeSlotScreen extends ConsumerStatefulWidget {
  const ChooseTimeSlotScreen({super.key});

  @override
  ConsumerState<ChooseTimeSlotScreen> createState() => _ChooseTimeSlotScreenState();
}

class _ChooseTimeSlotScreenState extends ConsumerState<ChooseTimeSlotScreen> {
  String? _selectedTimeSlot;

  // Mock data matching screenshot
  // final List<String> _morningSlots = ['09:00AM', '09:35 AM', '10:05 AM', '11:00 AM'];
  // final List<String> _afternoonSlots = ['12:00PM', '12:35 PM', '01:05 PM', '01:45 PM', '03:00 PM'];
  // final List<String> _eveningSlots = ['06:00PM', '07:00 PM', '08:05 PM', '09:00 PM'];

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final selectedDoctor = ref.watch(selectedDoctorProvider);
    final bookedSlots = ref.watch(bookedSlotsProvider).valueOrNull ?? [];

    if (selectedDoctor == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text("No doctor selected")),
      );
    }

    // Watch the live doctor stream to consistently get updated slots
    final doctorAsync = ref.watch(doctorStreamProvider(selectedDoctor.id));

    return doctorAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (doctor) {
        if (doctor == null) return const Scaffold(body: Center(child: Text("Doctor not found")));


    // Default slots (Fallback)
    final defaultMorningSlots = ['09:00 AM', '09:35 AM', '10:05 AM', '11:00 AM'];
    final defaultAfternoonSlots = ['12:00 PM', '12:35 PM', '01:05 PM', '01:45 PM', '03:00 PM'];
    final defaultEveningSlots = ['06:00 PM', '07:00 PM', '08:05 PM', '09:00 PM'];

    List<String> morningSlots = [];
    List<String> afternoonSlots = [];
    List<String> eveningSlots = [];

    // Get selected date
    final selectedDate = ref.watch(appointmentProvider)?.date ?? DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Check availability
    if (doctor.availableSlots.containsKey(dateKey)) {
      final available = doctor.availableSlots[dateKey]!;
      // Parse and categorize
      for (var slot in available) {
        try {
          // Assuming format "hh:mm a" e.g., "09:00 AM"
          final dt = DateFormat('hh:mm a').parse(slot);
          final hour = dt.hour; 
          
          if (hour < 12) {
            morningSlots.add(slot);
          } else if (hour < 18) {
            afternoonSlots.add(slot);
          } else {
            eveningSlots.add(slot);
          }
        } catch (e) {
          // Fallback if format is weird, put in afternoon? Or ignore
          print("Error parsing slot: $slot");
        }
      }
    } else {
      // Use defaults
      morningSlots = List.from(defaultMorningSlots);
      afternoonSlots = List.from(defaultAfternoonSlots);
      eveningSlots = List.from(defaultEveningSlots);
    }

    // Filter booked slots
    morningSlots = morningSlots.where((slot) => !bookedSlots.contains(slot)).toList();
    afternoonSlots = afternoonSlots.where((slot) => !bookedSlots.contains(slot)).toList();
    eveningSlots = eveningSlots.where((slot) => !bookedSlots.contains(slot)).toList();

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeroWidget(title: "Choose Time Slot", showBackButton: true),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 4, decoration: BoxDecoration(color: appColors.primary, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(right: 8))),
                        Expanded(child: Container(height: 4, decoration: BoxDecoration(color: appColors.primary, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(right: 8))),
                        Expanded(child: Container(height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      ],
                    ),
                  ),

                  // Doctor Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            doctor.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[300]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: appColors.text)),
                            const SizedBox(height: 2),
                            Text(doctor.specialization, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(height: 2),
                            Text("Consultation Fee - ₹ ${doctor.videoConsultationPrice.toInt()}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text("Pick a time slot", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appColors.text)),
                  ),
                  const SizedBox(height: 16),
                  
                  if (morningSlots.isNotEmpty) _buildSection("Morning", morningSlots, appColors),
                  if (afternoonSlots.isNotEmpty) _buildSection("Afternoon", afternoonSlots, appColors),
                  if (eveningSlots.isNotEmpty) _buildSection("Evening", eveningSlots, appColors),
                  
                  if (morningSlots.isEmpty && afternoonSlots.isEmpty && eveningSlots.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(24.0),
                       child: Center(child: Text("No blocks available for this date")),
                     )
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _selectedTimeSlot != null ? Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: appColors.background, 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                ref.read(appointmentProvider.notifier).updateAppointment(time: _selectedTimeSlot);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text("PROCEED TO PAYMENT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
      ) : null,
    );
      },
    );
  }

  Widget _buildSection(String title, List<String> slots, AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: appColors.text)),
         ),
         GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final isSelected = _selectedTimeSlot == slot;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTimeSlot = slot;
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? appColors.primary : appColors.background2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      color: isSelected ? appColors.themeColor : appColors.text,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
         ),
         const SizedBox(height: 16),
      ],
    );
  }
}
