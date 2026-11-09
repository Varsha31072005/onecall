import 'package:callone/app_styles/app_colors.dart';
import 'package:callone/providers/concern_provider.dart';
import 'package:callone/providers/navigation_provider.dart';
import 'package:callone/screens/appointments_screen.dart';
import 'package:callone/screens/dashboard.dart';
import 'package:callone/screens/profile_screen.dart';
import 'package:callone/screens/settings_screen.dart';
import 'package:callone/screens/auth/login_screen.dart';
import 'package:callone/services/auth_service.dart';
import 'package:callone/services/user_service.dart';
import 'package:callone/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';



import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:callone/config/zego_config.dart';

class WidgetTree extends ConsumerStatefulWidget {
  const WidgetTree({super.key});

  @override
  ConsumerState<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends ConsumerState<WidgetTree> {
  final ZegoUIKitSignalingPlugin _signalingPlugin = ZegoUIKitSignalingPlugin();
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    // Logic to run after build to check initial auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _checkAndInitZego();
    });
  }

  void _checkAndInitZego() {
    final user = ref.read(authStateProvider).value;
    if (user != null && !_isInit) {
      _initZego(user.uid, user.displayName ?? "User");
    }
  }

  Future<void> _initZego(String userId, String userName) async {
    if (_isInit) {
      debugPrint("Zego: Already initialized, skipping.");
      return;
    }
    
    debugPrint("Zego: Initializing for user $userId...");
    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: ZegoConfig.appId,
        appSign: ZegoConfig.appSign,
        userID: userId,
        userName: userName,
        plugins: [_signalingPlugin],
      );
      _isInit = true;
      debugPrint("Zego: Initialization SUCCESS");
    } catch (e) {
      debugPrint("Zego: Initialization FAILED: $e");
    }
  }

  Future<void> _uninitZego() async {
    if (!_isInit) return;
    
    try {
      debugPrint("Zego: Uninitializing...");
      await ZegoUIKitPrebuiltCallInvitationService().uninit();
      _isInit = false;
      debugPrint("Zego: Uninitialized SUCCESS");
    } catch (e) {
      debugPrint("Zego: Uninitialization FAILED: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    
    ref.listen(authStateProvider, (previous, next) {
       next.when(
         data: (user) {
           if (user != null) {
             _initZego(user.uid, user.displayName ?? "User");
           } else {
             _uninitZego();
           }
         },
         error: (_, __) => _uninitZego(),
         loading: () {},
       );
    });

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // Ensure uninit if we rendered this state
          if (_isInit) _uninitZego();
          return const LoginScreen();
        }
        
        // Use post-frame callback to init if strictly necessary from this path
        // but the listener/initState usually covers it. 
        // Failing that, we can do a safe check:
        if (!_isInit) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
               _initZego(user.uid, user.displayName ?? "User");
           });
        }
        
        final profileState = ref.watch(userProfileProvider(user.uid));
        
        return profileState.when(
          data: (snapshot) {
            final data = snapshot.data() as Map<String, dynamic>?;
            final bool profileCompleted = data?['profileCompleted'] ?? false;

            if (!profileCompleted) {
              return const ProfileScreen();
            }

            return const MainNavigationWrapper();
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }
}

class MainNavigationWrapper extends ConsumerWidget {
  const MainNavigationWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(navigationProvider);
    final String? selectedConcernId = ref.watch(concernProvider);
    final appColors = ref.watch(appColorsProvider);

    Widget content;
    switch (currentIndex) {
      case 0:
        content = const Dashboard();
        break;
      case 1:
        content = const AppointmentsScreen();
        break;
      case 3:
        content = const ProfileScreen();
        break;
      case 4:
        content = const SettingsScreen();
        break;
      default:
        content = const Dashboard();
        break;
    }

    return Scaffold(
      backgroundColor: appColors.background,
      body: content,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 70,
        width: 70,
        child: FloatingActionButton(
          tooltip: "Describe Concern",
          onPressed: () {
            if (selectedConcernId != null && selectedConcernId.isNotEmpty) {
              Navigator.pushNamed(context, '/your_concern');
            } else {
              showTopSnackBar(
                Overlay.of(context),
                const CustomSnackBar.error(
                  message: "Please select or type a concern first",
                ),
              );
            }
          },
          elevation: 10,
          backgroundColor: appColors.primary,
          shape: const CircleBorder(),
          child: const Icon(Icons.medical_services_outlined, color: Colors.white, size: 32,),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: currentIndex,
        onTap: (int index) {
          if (index != 2) {
            ref.read(navigationProvider.notifier).onchange(index);
          }
        },
      ),
    );
  }
}
