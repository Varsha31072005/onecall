import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecall_doctor/screens/home_screen.dart';
import 'package:onecall_doctor/widgets/bottom_nav.dart';

import 'package:onecall_doctor/screens/appointments/appointments_screen.dart';
import 'package:onecall_doctor/services/notification_service.dart';
import 'package:onecall_doctor/models/appointment_model.dart';
import 'package:onecall_doctor/screens/profile/profile_screen.dart';


import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:onecall_doctor/config/zego_config.dart';
import 'package:onecall_doctor/providers/auth_provider.dart';
import 'package:onecall_doctor/providers/appointment_provider.dart';

class WidgetTree extends ConsumerStatefulWidget {
  const WidgetTree({super.key});

  @override
  ConsumerState<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends ConsumerState<WidgetTree> with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<String> _knownAppointmentIds = [];
  bool _isFirstLoad = true;
  bool _isInit = false;

  final List<Widget> _pages = [
    const HomeScreen(),
    const AppointmentsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService().init();
    NotificationService().selectNotificationStream.stream.listen((payload) {
      if (payload == 'appointments') {
        setState(() {
          _currentIndex = 1;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _uninitZego();
    }
  }

  Future<void> _initZego(String userId, String userName) async {
    if (_isInit) return;

    debugPrint("Initializing Zego for Doctor: $userId ($userName)");
    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: ZegoConfig.appId,
        appSign: ZegoConfig.appSign,
        userID: userId,
        userName: userName,
        plugins: [ZegoUIKitSignalingPlugin()],
        notificationConfig: ZegoCallInvitationNotificationConfig(
          androidNotificationConfig: ZegoCallAndroidNotificationConfig(
            showOnFullScreen: true,
            callChannel: ZegoCallAndroidNotificationChannelConfig(
              channelID: "ZegoUIKit",
              channelName: "Call Notifications",
              sound: "call_ringtone",
              icon: "call_icon",
            ),
          ),
        ),
        requireConfig: (ZegoCallInvitationData data) {
          final config = (data.invitees.length > 1)
              ? ZegoCallInvitationType.videoCall == data.type
                  ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                  : ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
              : ZegoCallInvitationType.videoCall == data.type
                  ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                  : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

          // Add custom configuration here if needed
          return config;
        },
      );
      _isInit = true;
      debugPrint("Zego Doctor: Initialization SUCCESS");
    } catch (e) {
      debugPrint("Zego Doctor: Initialization FAILED: $e");
    }
  }

  void _uninitZego() {
    if (!_isInit) return;
    try {
      ZegoUIKitPrebuiltCallInvitationService().uninit();
      _isInit = false;
      debugPrint("Zego Doctor: Uninitialization SUCCESS");
    } catch (e) {
      debugPrint("Zego Doctor: Uninitialization FAILED: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uninitZego();
    super.dispose();
  }

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    // Listen to auth state changes to init/uninit Zego
    ref.listen(authStateChangesProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            _initZego(user.uid, user.displayName ?? "Doctor");
          } else {
            _uninitZego();
          }
        },
        error: (e, s) => _uninitZego(),
        loading: () {},
      );
    });

    // Check current auth state for Zego init (if already logged in)
    authState.whenData((user) {
      if (user != null && !_isInit) {
        _initZego(user.uid, user.displayName ?? "Doctor");
      }
    });

    // Listen to appointments to trigger notifications
    ref.listen<AsyncValue<List<Appointment>>>(appointmentsStreamProvider, (previous, next) {
      next.whenData((appointments) {
        if (_isFirstLoad) {
          _knownAppointmentIds = appointments.map((e) => e.id).toList();
          _isFirstLoad = false;
        } else {
          for (final appointment in appointments) {
            if (!_knownAppointmentIds.contains(appointment.id)) {
              // New appointment found!
              _knownAppointmentIds.add(appointment.id);

              NotificationService().showNotification(
                id: appointment.id.hashCode,
                title: "New Appointment",
                body: "You have a new appointment with ${appointment.userEmail}",
                payload: "appointments",
              );
            }
          }
        }
      });
    });

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
