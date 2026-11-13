import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/models/appointment_model.dart';
import 'package:onecall_doctor/providers/appointment_provider.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../config/zego_config.dart';

class CallScreen extends ConsumerWidget {
  final String callId;
  final String userId;
  final String userName;
  final Appointment appointment;

  const CallScreen({
    super.key,
    required this.callId,
    required this.userId,
    required this.userName,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = appointment.consultationType == "Video"
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();



    config.topMenuBar.buttons = [
      ZegoCallMenuBarButtonName.minimizingButton,
    ];

    config.bottomMenuBar.extendButtons = [
      GestureDetector(
        onTap: () {
          ref.read(completeAppointmentProvider(appointment));
          Navigator.pop(context);
        },
        child: const Tooltip(
          message: "Complete Consultation",
          child: Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
        ),
      ),
    ];

    return ZegoUIKitPrebuiltCall(
      appID: ZegoConfig.appId,
      appSign: ZegoConfig.appSign,
      userID: userId,
      userName: userName,
      callID: callId,
      config: config,
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) {
          ref.read(completeAppointmentProvider(appointment));
          defaultAction();
        },
      ),
    );
  }
}
