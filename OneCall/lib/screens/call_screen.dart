import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/zego_config.dart';
import '../widgets/prescription_dialog.dart';

class CallScreen extends StatelessWidget {
  final String callId;
  final String userId;
  final String userName;
  final String consultationType;

  const CallScreen({
    super.key,
    required this.callId,
    required this.userId,
    required this.userName,
    required this.consultationType,
  });

  @override
  Widget build(BuildContext context) {
    final config = consultationType == "Video"
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    // Add Prescription Button to Foreground
    config.foreground = Positioned(
      top: 50,
      right: 20,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .doc(callId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final doctorId = data['doctorId'];
          final patientId = data['patientId'];
          final prescription = data['prescription'] as String?;

          bool canWrite = userId == doctorId && (prescription == null || prescription.isEmpty);
          bool canView = (userId == doctorId && prescription != null && prescription.isNotEmpty) ||
                         (userId == patientId && prescription != null && prescription.isNotEmpty);

          if (!canWrite && !canView) return const SizedBox.shrink();

          return ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => PrescriptionDialog(
                  initialPrescription: prescription,
                  isReadOnly: !canWrite,
                  onSave: (text) async {
                    await FirebaseFirestore.instance
                        .collection('appointments')
                        .doc(callId)
                        .update({'prescription': text});
                  },
                ),
              );
            },
            icon: Icon(canWrite ? Icons.edit_note : Icons.receipt_long, color: Colors.white),
            label: Text(canWrite ? "Write Prescription" : "View Prescription"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Use a distinct color
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );

    return ZegoUIKitPrebuiltCall(
      appID: ZegoConfig.appId,
      appSign: ZegoConfig.appSign,
      userID: userId,
      userName: userName,
      callID: callId,
      config: config,
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) async {
          // Update Firestore status to completed
          try {
            await FirebaseFirestore.instance
                .collection('appointments')
                .doc(callId)
                .update({'status': 'completed'});
          } catch (e) {
            print("Error marking appointment as completed: $e");
          }
          defaultAction.call();
        },
      ),
    );
  }
}
