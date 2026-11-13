import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/widgets/app_bar.dart';
import 'package:callone/data/models/appointment.dart';
import 'package:callone/data/models/doctor.dart';
import 'package:callone/screens/call_screen.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/booking_service.dart';
import '../providers/doctors_provider.dart';
import 'package:callone/services/notification_service.dart';
import 'package:callone/providers/appointments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:callone/services/pdf_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';


class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  final Map<String, bool> _expanded = {};
  String _selectedFilter = 'Upcoming';

  Doctor? _getDoctor(String doctorId, List<Doctor> doctors) {
    try {
      return doctors.firstWhere((d) => d.id == doctorId);
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final dayName = days[date.weekday - 1];
    return "$dayName, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Widget _buildDetailRow(String label, String value, AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: appColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, AppointmentModel appointment, Doctor doctor) {
    double rating = 0;
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Rate Dr. ${doctor.name}"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How was your consultation?"),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (r) {
                rating = r;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Describe your experience...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (rating == 0) {
                 showTopSnackBar(
                   Overlay.of(context),
                   const CustomSnackBar.error(message: "Please select a rating"),
                 );
                 return;
              }
              
              if (reviewController.text.trim().isEmpty) {
                 showTopSnackBar(
                   Overlay.of(context),
                   const CustomSnackBar.error(message: "Please add a description of your experience"),
                 );
                 return;
              }

              try {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                
                await BookingService().rateDoctor(
                  appointment.id!, 
                  doctor.id, 
                  rating, 
                  reviewController.text.trim()
                );
                
                if (context.mounted) {
                   Navigator.pop(context); // Pop loading
                   Navigator.pop(context); // Pop rating dialog
                   showTopSnackBar(
                     Overlay.of(context),
                     const CustomSnackBar.success(message: "Thank you for your rating!"),
                   );
                }
              } catch (e) {
                 if (context.mounted) {
                   Navigator.pop(context); // Pop loading
                   showTopSnackBar(
                     Overlay.of(context),
                     CustomSnackBar.error(message: "Error: $e"),
                   );
                 }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffD98F56),
              foregroundColor: Colors.white,
            ),
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final appColors = ref.watch(appColorsProvider);
    final doctorsAsyncValue = ref.watch(doctorsProvider);

    if (user != null) {
      ref.listen<AsyncValue<List<AppointmentModel>>>(
          userAppointmentsProvider(user.uid), (previous, next) {
        next.whenData((newAppointments) {
          previous?.whenData((oldAppointments) {
            for (var newApp in newAppointments) {
              final oldApp = oldAppointments.firstWhere(
                  (a) => a.id == newApp.id,
                  orElse: () => AppointmentModel(
                      patientId: '',
                      concernId: '',
                      doctorId: '',
                      consultationType: '',
                      date: DateTime.now(),
                      time: '',
                      severity: 0,
                      duration: '',
                      durationType: '',
                      userEmail: '',
                      doctorEmail: ''));

              // Check if prescription changed or added
              if (oldApp.id == newApp.id &&
                  oldApp.prescription != newApp.prescription &&
                  newApp.prescription != null &&
                  newApp.prescription!.isNotEmpty) {
                NotificationService().showNotification(
                  id: newApp.id.hashCode,
                  title: 'Prescription Updated',
                  body: 'Dr. has updated the prescription for your appointment on ${newApp.time}',
                );
              }
              
              // Check if appointment cancelled by doctor
              if (oldApp.status != 'cancelled' && newApp.status == 'cancelled' && newApp.cancelledBy == 'doctor') {
                 NotificationService().showNotification(
                   id: newApp.id.hashCode,
                   title: 'Appointment Cancelled',
                   body: 'Doctor has cancelled your appointment on ${newApp.time}',
                 );
              }
            }
          });
        });
      });
    }

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppAppBar(name: "My Bookings"),
      body: user == null
          ? const Center(child: Text("Please login to view appointments"))
          : doctorsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text("Error loading doctors: $err")),
              data: (doctors) {
                final appointmentsAsync =
                    ref.watch(userAppointmentsProvider(user.uid));

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: appColors.background,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFilter = 'Upcoming'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == 'Upcoming'
                                      ? appColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _selectedFilter == 'Upcoming'
                                        ? appColors.primary
                                        : Colors.grey.shade300,
                                  ),
                                  boxShadow: _selectedFilter == 'Upcoming'
                                      ? [
                                          BoxShadow(
                                            color: appColors.primary.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    "Upcoming",
                                    style: TextStyle(
                                      color: _selectedFilter == 'Upcoming'
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFilter = 'Completed'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == 'Completed'
                                      ? appColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _selectedFilter == 'Completed'
                                        ? appColors.primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Completed",
                                    style: TextStyle(
                                      color: _selectedFilter == 'Completed'
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFilter = 'Cancelled'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == 'Cancelled'
                                      ? Colors.red.shade400
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _selectedFilter == 'Cancelled'
                                        ? Colors.red.shade400
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Cancelled",
                                    style: TextStyle(
                                      color: _selectedFilter == 'Cancelled'
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: appointmentsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) =>
                            Center(child: Text("Error: $err")),
                        data: (appointments) {
                          final filteredAppointments = appointments.where((a) {
                            if (_selectedFilter == 'Completed') {
                              return a.status == 'completed';
                            }
                            if (_selectedFilter == 'Cancelled') {
                              return a.status == 'cancelled';
                            }
                            return a.status == 'upcoming' || a.status == 'accepted';
                          }).toList();

                          if (filteredAppointments.isEmpty) {
                            return Center(
                                child: Text(
                                    "No ${_selectedFilter.toLowerCase()} appointments found"));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredAppointments.length,
                            itemBuilder: (context, index) {
                              final appointment = filteredAppointments[index];
                              final doctor =
                                  _getDoctor(appointment.doctorId, doctors);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                    color: appColors.background2,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4))
                                    ]),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doctor?.name ?? "Dr. Unknown",
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: appColors.text),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                        doctor?.specialization ??
                                                            "Specialist",
                                                        style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 13)),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 4),
                                                      decoration: BoxDecoration(
                                                          color: const Color(
                                                              0xffFFF2E3), // Light orange
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  20)),
                                                      child: Text(
                                                        appointment.status == 'completed'
                                                            ? "Completed"
                                                            : (appointment.status == 'cancelled' ? "Cancelled" : "Upcoming"),
                                                        style: TextStyle(
                                                            color: appointment.status == 'cancelled'
                                                                ? Colors.red
                                                                : const Color(0xffD98F56),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold)),
                                                    )
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: doctor != null
                                                ? Image.network(doctor.imageUrl,
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, o, s) =>
                                                        Container(
                                                            color: Colors.grey[300],
                                                            width: 50,
                                                            height: 50,
                                                            child: Icon(
                                                                Icons.person)))
                                                : Container(
                                                    color: Colors.grey[300],
                                                    width: 50,
                                                    height: 50,
                                                    child: Icon(Icons.person)),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Date & Time
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_outlined,
                                              size: 16, color: appColors.primary),
                                          const SizedBox(width: 6),
                                          Text(_formatDate(appointment.date),
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13)),
                                          const SizedBox(width: 16),
                                          Icon(Icons.access_time,
                                              size: 16, color: appColors.primary),
                                          const SizedBox(width: 6),
                                          Text(appointment.time,
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Buttons
                                      Row(
                                        children: [
                                          Expanded(
                                              child: TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _expanded[appointment.id!] =
                                                    !(_expanded[appointment.id] ??
                                                        false);
                                              });
                                            },
                                            child: Text(
                                                (_expanded[appointment.id] ?? false)
                                                    ? "Hide Details"
                                                    : "View Details",
                                                style: TextStyle(
                                                    color: const Color(0xff41634A),
                                                    fontWeight: FontWeight.bold)),
                                          )),
                                          if (appointment.status == 'upcoming' || appointment.status == 'accepted') ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                      if (doctor != null &&
                                                          appointment.id !=
                                                              null) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                CallScreen(
                                                              callId:
                                                                  appointment.id!,
                                                              userId: user.uid,
                                                              consultationType:
                                                                  appointment
                                                                      .consultationType,
                                                              userName: (user.displayName != null && user.displayName!.isNotEmpty)
                                                                  ? user.displayName!
                                                                  : "User",
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        "Cannot start call: Missing appointment ID or doctor info")));
                                                      }
                                                    },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: appColors.primary,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(25),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                      vertical: 10),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  "Start Call",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ] else if (appointment.status == 'completed' && !appointment.isRated) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (doctor != null) {
                                                    _showRatingDialog(context, appointment, doctor);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.amber,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  "Rate Doctor",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ] else if (appointment.status == 'completed' && appointment.isRated) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: null,
                                                icon: const Icon(Icons.check, size: 16, color: Colors.green),
                                                label: const Text("Rated", style: TextStyle(color: Colors.green)),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.green),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      if (_expanded[appointment.id] ?? false)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: appColors.background,
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Appointment Details",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: appColors.text,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _buildDetailRow(
                                                  "Patient Email",
                                                  appointment.userEmail,
                                                  appColors),
                                              _buildDetailRow("Concern",
                                                  appointment.concernId, appColors),
                                              _buildDetailRow(
                                                  "Consultation",
                                                  appointment.consultationType,
                                                  appColors),
                                              _buildDetailRow(
                                                  "Duration",
                                                  "${appointment.duration} ${appointment.durationType}",
                                                  appColors),
                                              _buildDetailRow(
                                                  "Severity",
                                                  "${(appointment.severity + 1).toString()}/3.0",
                                                  appColors),
                                              if (doctor != null) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  "Doctor Information",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: appColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                _buildDetailRow(
                                                    "Experience",
                                                    "${doctor.experience} years",
                                                    appColors),
                                                _buildDetailRow(
                                                    "Fees",
                                                    "\$${appointment.consultationType == 'Video' ? doctor.videoConsultationPrice.toInt() : doctor.phoneConsultationPrice}",
                                                    appColors),
                                                if (appointment.prescription !=
                                                    null) ...[
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    "Prescription",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: appColors.text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      border: Border.all(
                                                          color: Colors.blue
                                                              .withOpacity(0.3)),
                                                    ),
                                                    child: Text(
                                                      appointment.prescription!,
                                                      style: TextStyle(
                                                        color: appColors.text,
                                                        fontSize: 14,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Center(
                                                    child: TextButton.icon(
                                                      onPressed: () {
                                                        PdfService().generatePrescriptionPdf(
                                                          doctor: doctor,
                                                          appointment: appointment,
                                                          patientName: (user.displayName != null && user.displayName!.isNotEmpty) ? user.displayName! : "User",
                                                          patientEmail: user.email ?? "Unknown",
                                                        );
                                                      },
                                                      icon: const Icon(Icons.download_rounded),
                                                      label: const Text("Download Prescription"),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: appColors.primary,
                                                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),

                                                ],
                                              ],
                                        if (appointment.status == 'upcoming' || appointment.status == 'accepted') ...[
                                        const SizedBox(height: 16),
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text("Cancel Appointment"),
                                                  content: const Text(
                                                      "Are you sure you want to cancel this appointment? \n\nYou will receive a 50% refund to your wallet."),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text("No"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        Navigator.pop(context); // Close Confirmation
                                                        try {
                                                          // Show loading
                                                          showDialog(
                                                            context: context,
                                                            barrierDismissible: false,
                                                            builder: (context) => const Center(child: CircularProgressIndicator()),
                                                          );

                                                          double price = appointment.consultationType == 'Video' 
                                                              ? (doctor?.videoConsultationPrice ?? 0) 
                                                              : (doctor?.phoneConsultationPrice ?? 0);
                                                          
                                                            await BookingService().cancelAppointment(
                                                            appointment.id!,
                                                            appointment.doctorId,
                                                            user.uid,
                                                            price,
                                                            true, // isPatient,
                                                            appointment.doctorEmail,
                                                            doctor?.name ?? "Doctor",
                                                            appointment.date,
                                                          );

                                                          if (context.mounted) {
                                                            Navigator.pop(context); // Close Loading
                                                            showTopSnackBar(
                                                              Overlay.of(context),
                                                              const CustomSnackBar.success(message: "Appointment cancelled. 50% refunded."),
                                                            );
                                                          }
                                                        } catch (e) {
                                                          if (context.mounted) {
                                                            Navigator.pop(context); // Close Loading
                                                            showTopSnackBar(
                                                              Overlay.of(context),
                                                              CustomSnackBar.error(message: "Failed to cancel: $e"),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                      child: const Text("Yes, Cancel"),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red.shade50,
                                              foregroundColor: Colors.red,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            ),
                                            child: const Text("Cancel Appointment"),
                                          ),
                                        ),
                                        ]
                                            ],
                                          ),
                                        ),


                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      );
  }
}