import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/models/concern.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:onecall_doctor/screens/profile/doctor_profile_setup_screen.dart';
import 'package:onecall_doctor/screens/schedule_screen.dart';

import '../../widgets/app_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsyncValue = ref.watch(currentDoctorStreamProvider);

    return Scaffold(
      appBar: AppAppBar(
        name: 'PROFILE',
        actions: [
          IconButton(
            onPressed: () async{
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ]
      ),
      body: doctorAsyncValue.when(
        data: (doctor) {
          if (doctor == null) {
            return const Center(child: Text("Doctor profile not found."));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: doctor.imageUrl.isNotEmpty
                            ? NetworkImage(doctor.imageUrl)
                            : null,
                        child: doctor.imageUrl.isEmpty
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        doctor.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        doctor.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Wallet"),
                _buildInfoRow("Balance", "₹${doctor.wallet.toStringAsFixed(2)}"),
                const SizedBox(height: 24),
                _buildSectionHeader("Professional Info"),
                _buildInfoRow("Specialization", doctor.specialization),
                _buildInfoRow("Experience", "${doctor.experience} years"),
                _buildInfoRow("Languages", doctor.languages.join(", ")),
                const SizedBox(height: 24),
                _buildSectionHeader("Consultation Fees"),
                _buildInfoRow("Video Call", "₹${doctor.videoConsultationPrice.toStringAsFixed(2)}"),
                _buildInfoRow("Phone Call", "₹${doctor.phoneConsultationPrice.toStringAsFixed(2)}"),
                const SizedBox(height: 24),
                _buildSectionHeader("About"),
                Text(
                  doctor.about.isEmpty ? "No information provided." : doctor.about,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Areas of Concern"),
                if (doctor.concernId.isEmpty)
                  const Text("No concerns selected.")
                else
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: doctor.concernId.map((id) {
                      final concern = concerns.firstWhere(
                        (c) => c.id == id,
                        orElse: () => Concern(id: id, title: id, icon: Icons.help),
                      );
                      return Chip(
                        label: Text(concern.title),
                        avatar: Icon(concern.icon, size: 16),
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScheduleScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Manage Schedule"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff3A643B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorProfileSetupScreen(doctor: doctor),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // Different style to distinguish
                      foregroundColor: const Color(0xff3A643B),
                      side: const BorderSide(color: Color(0xff3A643B)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xff3A643B),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
