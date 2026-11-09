import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/data/models/doctor.dart';
import 'package:callone/providers/selected_doctor_provider.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/user_service.dart';
import 'package:callone/providers/navigation_provider.dart';
import 'package:callone/providers/last_payment_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = ref.watch(appColorsProvider);
    final doctor = ref.watch(selectedDoctorProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final paidAmount = ref.watch(lastPaymentProvider);

    return Scaffold(
      backgroundColor: appColors.background2,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
               // Header info (time/status bar usually, but safe area handles it)
               
               const Spacer(),
               // Profile Image & Checkmark
               Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.transparent, // Or white if needed
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: doctor != null
                            ? Image.network(
                                doctor.imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 50),
                                ),
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(Icons.person, size: 50),
                              ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 10),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.check_circle, 
                          color: Color(0xff67B26F), 
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Payment Amount
                Text(
                  "Paid ₹${paidAmount.toInt()}",
                  style: TextStyle(
                    color: appColors.text, // Usually dark green/black
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Consultation Booked Successfully",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Wallet Balance
                Icon(Icons.account_balance_wallet_outlined, color: Colors.grey[500], size: 28),
                const SizedBox(height: 8),
                Text(
                  "Available Balance",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                 if (user != null)
                    ref.watch(userProfileProvider(user.uid)).when(
                          data: (snapshot) {
                            final data = snapshot.data() as Map<String, dynamic>? ?? {};
                            final balance = data['walletBalance'] ?? 660; // Mock default if not found
                            return Text(
                                "₹ ${balance}",
                                style: TextStyle(
                                  color: appColors.text,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                          },
                          loading: () => const Text("₹ ...", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          error: (_, __) => const Text("₹ Error", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        ),


                const Spacer(flex: 2),

                // Check Bookings Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Switch to Appointments tab (Index 1)
                      ref.read(navigationProvider.notifier).onchange(1);
                      // // Pop until root (WidgetTree)
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff41634A), // Dark green button
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: const Text("Check Bookings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                 Container(
                  width: 140,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10)
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
