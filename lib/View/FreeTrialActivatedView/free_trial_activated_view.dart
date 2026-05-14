import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Local/local_db_keys.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FreeTrialActivatedView extends ConsumerStatefulWidget {
  const FreeTrialActivatedView({super.key});

  /// Ekranı göstermeden, video/sohbet kapısı sonrası ile aynı yönlendirme (login veya ana sekmeler).
  static Future<void> applyPostOnboardingTrialRouting({
    required WidgetRef ref,
    required BuildContext context,
    required bool forceLogoutToLogin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final isOnboardingGuestSession = localService.isOnboardingGuestSession();
    final shouldGoToLogin = forceLogoutToLogin || isOnboardingGuestSession;

    if (shouldGoToLogin) {
      await Future.wait([
        LocalService.deleteData(LocalDbKeys.authToken),
        LocalService.deleteData(LocalDbKeys.refreshToken),
        LocalService.deleteData(LocalDbKeys.currentUser),
        LocalService.deleteData(LocalDbKeys.onboardingPendingAuth),
        LocalService.deleteData(LocalDbKeys.onboardingGuestSession),
        LocalService.deleteData(LocalDbKeys.onboardingVideoGatePending),
        LocalService.deleteData(LocalDbKeys.onboardingFunnelActive),
      ]);
      ref.read(AllControllers.userController.notifier).updateUserModel(null);
    }

    if (!context.mounted) return;
    if (shouldGoToLogin) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/bottomNavbar', (route) => false);
    }
  }

  @override
  ConsumerState<FreeTrialActivatedView> createState() => _FreeTrialActivatedViewState();
}

class _FreeTrialActivatedViewState extends ConsumerState<FreeTrialActivatedView> {
  bool _switchOn = false;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _switchOn = true);
      _continueFlow();
    });
  }

  Future<void> _continueFlow() async {
    if (_didComplete) return;
    _didComplete = true;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final forceLogoutToLogin =
        routeArgs is Map && routeArgs["forceLogoutToLogin"] == true;

    await FreeTrialActivatedView.applyPostOnboardingTrialRouting(
      ref: ref,
      context: context,
      forceLogoutToLogin: forceLogoutToLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TrialToggleVisual(isOn: _switchOn),
              SizedBox(height: 16.h),
              Text(
                "3-day free trial",
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                "activated",
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrialToggleVisual extends StatelessWidget {
  final bool isOn;

  const _TrialToggleVisual({required this.isOn});

  static const _activeColor = Color(0xFFAB10E2);
  static const _inactiveColor = Color(0xFFE6E0E9);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isOn ? 1.14 : 1.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOn ? _activeColor : const Color(0xff79747E),
            width: 2,
          ),
          color: isOn
              ? _activeColor
              : const Color(0xffE6E0E9),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isOn ? Colors.white : const Color(0xff79747E),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
