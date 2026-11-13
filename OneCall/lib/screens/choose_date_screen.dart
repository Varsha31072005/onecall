import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/appointment_provider.dart';
import 'package:callone/providers/selected_doctor_provider.dart';
import 'package:callone/widgets/hero_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChooseDateScreen extends ConsumerStatefulWidget {
  const ChooseDateScreen({super.key});

  @override
  ConsumerState<ChooseDateScreen> createState() => _ChooseDateScreenState();
}

class _ChooseDateScreenState extends ConsumerState<ChooseDateScreen> {
  late List<DateTime> _dates;
  DateTime? _selectedDate;

  final List<String> _months = const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  final List<String> _fullMonths = const [
     '', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> _weekdays = const [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _generateDates();
  }

  void _generateDates() {
    final now = DateTime.now();
    _dates = List.generate(15, (index) {
      return now.add(Duration(days: index + 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = ref.watch(appColorsProvider);
    final doctor = ref.watch(selectedDoctorProvider);

    if (doctor == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text("No doctor selected")),
      );
    }

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeroWidget(title: "Choose Date", showBackButton: true),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 4, decoration: BoxDecoration(color: appColors.primary, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(right: 8))),
                        Expanded(child: Container(height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(right: 8))),
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
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text("Pick Appointment Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appColors.text)),
                  ),
                  const SizedBox(height: 16),

                  // Date Grid
                  GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _dates.length,
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      final isSelected = _selectedDate != null && 
                                         date.year == _selectedDate!.year && 
                                         date.month == _selectedDate!.month && 
                                         date.day == _selectedDate!.day;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? appColors.primary : appColors.background2,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${date.day.toString().padLeft(2, '0')} ${_months[date.month]}",
                                style: TextStyle(
                                  color: isSelected ? appColors.themeColor : appColors.text,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: isSelected ? 17 : 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _weekdays[date.weekday],
                                style: TextStyle(
                                  color: isSelected ? appColors.themeColor : appColors.text.withOpacity(0.8),
                                  fontSize: isSelected ? 15 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 120), // Space for bottom sheet
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _selectedDate != null ? Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: appColors.colortint,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Container(
               width: double.infinity,
               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
               decoration: BoxDecoration(
                 color: appColors.background2,
                 borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.calendar_today, size: 16, color: appColors.primary),
                   const SizedBox(width: 8),
                   Text(
                     "${_selectedDate!.day.toString().padLeft(2, '0')} ${_fullMonths[_selectedDate!.month]} ${_selectedDate!.year}",
                     style: TextStyle(color: appColors.primary, fontWeight: FontWeight.w600),
                   ),
                 ],
               ),
             ),
             SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                   ref.read(appointmentProvider.notifier).updateAppointment(date: _selectedDate);
                   Navigator.pushNamed(context, '/choose_time_slot');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  ),
                  elevation: 0,
                ),
                child: const Text("CONFIRM DATE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ) : null,
    );
  }
}
