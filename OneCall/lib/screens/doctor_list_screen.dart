import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/doctors_provider.dart';


import '../widgets/app_bar.dart';
import '../widgets/doctor_card.dart';
import '../data/models/doctor.dart';
import '../data/models/concern.dart';
import '../repositories/doctor_repo.dart';
import '../app_styles/app_colors.dart';


class DoctorListScreen extends ConsumerStatefulWidget {
  const DoctorListScreen({super.key});

  @override
  ConsumerState<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends ConsumerState<DoctorListScreen> {
  String? _selectedConcernId;
  String? _recommendedSpecialty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _selectedConcernId == null) {
      _selectedConcernId = args['concernId'] as String?;
      _recommendedSpecialty = args['specialty'] as String?;
    } else if (args is String && _selectedConcernId == null) {
      _selectedConcernId = args;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final doctorsAsyncValue = ref.watch(doctorsProvider);

    return Scaffold(
      appBar: AppAppBar(
        name: "Select Doctor",
      ),
      backgroundColor: appColors.background,
      body: Column(
        children: [
          // AI Recommendation Banner if coming from AI Assistant
          if (_recommendedSpecialty != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: appColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: appColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: appColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "AI Recommended Specialty: $_recommendedSpecialty",
                      style: TextStyle(
                        color: appColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Filter section
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', 'All', appColors),
                ...concerns.map((concern) => _buildFilterChip(concern.title, concern.id, appColors)),
              ],
            ),
          ),
          
          // Doctors List
          Expanded(
            child: doctorsAsyncValue.when(
              data: (doctors) {
                // Filter doctors by concern or specialty keyword
                List<Doctor> filteredDoctors = doctors;
                if (_recommendedSpecialty != null || (_selectedConcernId != null && _selectedConcernId != 'All')) {
                  final filtered = doctors.where((doc) {
                    final matchesConcern = _selectedConcernId != null && _selectedConcernId != 'All' &&
                        (doc.concernId.contains(_selectedConcernId!) || 
                         doc.specialization.toLowerCase().contains(_selectedConcernId!.toLowerCase()));
                    final matchesSpecialty = _recommendedSpecialty != null && (
                        doc.specialization.toLowerCase().contains(_recommendedSpecialty!.split(' ').first.toLowerCase()) ||
                        _recommendedSpecialty!.toLowerCase().contains(doc.specialization.toLowerCase().split(' ').first));
                    return matchesConcern || matchesSpecialty;
                  }).toList();

                  // If matched, use filtered, otherwise show all doctors with recommendation banner
                  filteredDoctors = filtered.isNotEmpty ? filtered : doctors;
                }

                if (filteredDoctors.isEmpty) {
                   return Center(child: Text("No doctors found", style: TextStyle(color: Colors.grey[600])));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filteredDoctors.length,
                  itemBuilder: (context, index) {
                    return DoctorCard(doctor: filteredDoctors[index]);
                  },
                );
              },
              error: (error, stackTrace) => Center(child: Text("Error: $error")),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String id, AppColors appColors) {
    final bool isSelected = (id == 'All' && (_selectedConcernId == null || _selectedConcernId == 'All')) || 
                            (id != 'All' && _selectedConcernId == id);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedConcernId = id == 'All' ? null : id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? appColors.primary.withOpacity(0.1) : appColors.background2,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? appColors.primary : appColors.background2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? appColors.primary : appColors.text,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
