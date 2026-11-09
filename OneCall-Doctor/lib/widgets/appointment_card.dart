import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onecall_doctor/models/appointment_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:onecall_doctor/screens/call_screen.dart';
import 'package:onecall_doctor/services/appointment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class AppointmentCard extends ConsumerStatefulWidget {
  final Appointment appointment;
  final VoidCallback? onCheckPrescription;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onCheckPrescription,
  });

  @override
  ConsumerState<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<AppointmentCard> {
  bool _isExpanded = false;

  Future<void> _handleFile(String pathOrUrl) async {
    try {
      // 1. If it's already a full HTTP URL
      if (pathOrUrl.startsWith('http')) {
        final Uri url = Uri.parse(pathOrUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          _showError("Could not open this link");
        }
        return;
      }

      // 2. If it's a Firebase Storage Path (e.g., 'health_files/abc.jpg')
      // OR if it's a local path from patient device, we try to fetch it from storage
      // using the filename as a fallback.

      String fileName = p.basename(pathOrUrl);

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloading file..."), duration: Duration(seconds: 2)),
      );

      // Attempt to download from Firebase Storage
      // We'll try to find the file in a 'health_files' or similar folder if it's just a name
      Reference ref;
      if (pathOrUrl.contains('/')) {
        ref = FirebaseStorage.instance.ref(pathOrUrl);
      } else {
        ref = FirebaseStorage.instance.ref().child('health_files').child(fileName);
      }

      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/$fileName');

      await ref.writeToFile(tempFile);

      // Open the downloaded file
      // final result = await OpenFile.open(tempFile.path);
      // if (result.type != ResultType.done) {
      //   _showError("Could not open file: ${result.message}");
      // }

    } catch (e) {
      debugPrint('Error handling file: $e');
      // If download failed, it might be because the patient saved a local path incorrectly
      if (pathOrUrl.contains('/data/user/0/')) {
        _showLocalPathError();
      } else {
        _showError("Error: $e");
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLocalPathError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("File Unreachable"),
        content: const Text(
            "This file was saved as a local path on the patient's device and is not available in the cloud. \n\nPlease ask the patient to re-upload the file."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final isCompleted = appointment.status == 'completed';
    final isUpcoming = appointment.status == 'upcoming' || appointment.status == 'accepted';

    final statusColor =
        isCompleted ? const Color(0xffE8F5E9) : const Color(0xffFFF3E0);
    final statusTextColor =
        isCompleted ? const Color(0xff3A643B) : const Color(0xffE65100);
    final statusText = isCompleted ? "Completed" : (appointment.status == 'accepted' ? "Accepted" : "Upcoming");

    final formattedDate =
        DateFormat('EEEE, dd/MM/yyyy').format(appointment.date);
    final displayTime = appointment.time;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.userEmail,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (appointment.triageUrgency != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: appointment.triageUrgency!.toUpperCase() == 'HIGH'
                                  ? Colors.red.shade50
                                  : (appointment.triageUrgency!.toUpperCase() == 'MEDIUM'
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: appointment.triageUrgency!.toUpperCase() == 'HIGH'
                                    ? Colors.red.shade300
                                    : (appointment.triageUrgency!.toUpperCase() == 'MEDIUM'
                                        ? Colors.orange.shade300
                                        : Colors.green.shade300),
                              ),
                            ),
                            child: Text(
                              "${appointment.triageUrgency!.toUpperCase() == 'HIGH' ? '🚨' : (appointment.triageUrgency!.toUpperCase() == 'MEDIUM' ? '⚠️' : '✅')} ${appointment.triageUrgency!.toUpperCase()} URGENCY",
                              style: TextStyle(
                                color: appointment.triageUrgency!.toUpperCase() == 'HIGH'
                                    ? Colors.red.shade800
                                    : (appointment.triageUrgency!.toUpperCase() == 'MEDIUM'
                                        ? Colors.orange.shade800
                                        : Colors.green.shade800),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(width: 24),
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                displayTime,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Appointment Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Patient Email:', appointment.userEmail),
                  _buildDetailRow(
                      'Consultation Type:', appointment.consultationType),
                  _buildDetailRow('Concern ID:', appointment.concernId),
                  _buildDetailRow('Severity:', '${appointment.severity}/3.0'),
                  _buildDetailRow('Duration:',
                      '${appointment.duration} ${appointment.durationType}'),
                  // AI Clinical Pre-Consultation Summary
                  if (appointment.triageUrgency != null || appointment.patientQuery != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appointment.triageUrgency?.toUpperCase() == 'HIGH'
                            ? Colors.red.shade50
                            : const Color(0xffF4FBF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appointment.triageUrgency?.toUpperCase() == 'HIGH'
                              ? Colors.red.shade200
                              : const Color(0xff3A643B).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: appointment.triageUrgency?.toUpperCase() == 'HIGH' ? Colors.red : const Color(0xff3A643B)),
                              const SizedBox(width: 6),
                              Text(
                                "AI Clinical Briefing",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: appointment.triageUrgency?.toUpperCase() == 'HIGH' ? Colors.red.shade900 : const Color(0xff3A643B),
                                ),
                              ),
                            ],
                          ),
                          if (appointment.predictedSpecialty != null) ...[
                            const SizedBox(height: 6),
                            Text("Matched Specialty: ${appointment.predictedSpecialty}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                          if (appointment.patientQuery != null && appointment.patientQuery!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text("Symptoms: \"${appointment.patientQuery}\"", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                          if (appointment.detectedRedFlags != null && appointment.detectedRedFlags!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              children: appointment.detectedRedFlags!.map((flag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text("⚠️ $flag", style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                              )).toList(),
                            ),
                          ],
                          if (appointment.clinicalAdvisory != null) ...[
                            const SizedBox(height: 6),
                            Text(appointment.clinicalAdvisory!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (appointment.description != null && appointment.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Description:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      appointment.description!,
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Health Files:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (appointment.healthFiles != null &&
                      appointment.healthFiles!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: appointment.healthFiles!.map((path) {
                        return InkWell(
                          onTap: () => _handleFile(path),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.insert_drive_file,
                                    size: 16, color: Colors.blue),
                                SizedBox(width: 6),
                                Text("Health File",
                                    style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text("No health files uploaded",
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  if (isUpcoming && appointment.status != 'accepted')
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          if (isCompleted) return;
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Cancel Appointment"),
                              content: const Text(
                                  "Are you sure you want to cancel this appointment? \n\nThis will initiate a 100% refund to the patient."),
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
                                        builder: (context) => const Center(
                                            child: CircularProgressIndicator()),
                                      );

                                      final user = ref
                                          .read(firebaseAuthProvider)
                                          .currentUser;
                                      final doctorName =
                                          user?.displayName ?? "Doctor";

                                      await AppointmentService()
                                          .cancelAppointment(
                                        appointment.id,
                                        appointment.doctorId,
                                        appointment.patientId,
                                        appointment.price,
                                        appointment.userEmail,
                                        doctorName,
                                        appointment.date,
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context); // Close Loading
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Appointment cancelled. Refund processing.")),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        Navigator.pop(context); // Close Loading
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text("Failed to cancel: $e")),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text("Cancel Appointment"),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff3A643B),
                    side: const BorderSide(color: Color(0xff3A643B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_isExpanded ? "Hide Details" : "View Details"),
                ),
              ),
              if (isUpcoming)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: ElevatedButton(
                      onPressed: () {
                        final user =
                            ref.read(firebaseAuthProvider).currentUser;
                        if (user != null) {
                          final displayName = user.displayName;
                          final userName =
                              (displayName != null && displayName.isNotEmpty)
                                  ? displayName
                                  : "Doctor";

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CallScreen(
                                callId: appointment.id,
                                userId: user.uid,
                                userName: userName,
                                appointment: appointment,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff3A643B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text("Join Call"),
                    ),
                  ),
                ),
            ],
          ),
          if (isCompleted && widget.onCheckPrescription != null) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: widget.onCheckPrescription,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(25),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Write Prescription",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xff333333))),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(
            width: 10,
          ),
          Flexible(
              child: Text(
            value,
            textAlign: TextAlign.end,
          )),
        ],
      ),
    );
  }
}
