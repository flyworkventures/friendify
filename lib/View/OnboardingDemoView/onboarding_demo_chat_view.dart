import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingDemoChatView extends ConsumerStatefulWidget {
  const OnboardingDemoChatView({super.key});

  @override
  ConsumerState<OnboardingDemoChatView> createState() =>
      _OnboardingDemoChatViewState();
}

class _OnboardingDemoChatViewState extends ConsumerState<OnboardingDemoChatView> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint("🧭 [OnboardingDemoChat] initState");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("🧭 [OnboardingDemoChat] postFrame -> _startRealChatFlow");
      _startRealChatFlow();
    });
  }

  Future<void> _startRealChatFlow() async {
    debugPrint("🧭 [OnboardingDemoChat] flow start");
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    await localService.setOnboardingFunnelActive(true);
    await localService.setOnboardingVideoGatePending(true);
    await localService.setOnboardingGuestSession(false);
    debugPrint(
      "🧭 [OnboardingDemoChat] flags set onboardingFunnelActive=true onboardingVideoGatePending=true onboardingGuestSession=false",
    );

    final user = ref.read(AllControllers.userController);
    final hasValidToken = user != null && user.token != null && user.token!.isNotEmpty;
    debugPrint(
      "🧭 [OnboardingDemoChat] user id=${user?.id} credential=${user?.credential} hasValidToken=$hasValidToken tokenLen=${user?.token?.length ?? 0}",
    );

    if (!hasValidToken) {
      debugPrint(
        "🧭 [OnboardingDemoChat] no token -> guestLogin (register path has no OAuth email yet)",
      );
      final guestOk = await ref
          .read(AllControllers.onboardViewController.notifier)
          .guestLogin(navigateToHome: false);
      if (!guestOk) {
        debugPrint("🧭 [OnboardingDemoChat] guestLogin failed -> /login");
        if (!mounted) return;
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        return;
      }
      await localService.setOnboardingGuestSession(true);
      debugPrint(
        "🧭 [OnboardingDemoChat] guestLogin ok onboardingGuestSession=true",
      );
    }

    debugPrint("🧭 [OnboardingDemoChat] fetching agents");
    await ref.read(AllControllers.agentsViewController.notifier).getAgents();
    final allAgents = ref.read(AllControllers.agentsViewController).agents ?? [];
    final agents = allAgents.where((a) => a.system != 2).toList();
    debugPrint(
      "🧭 [OnboardingDemoChat] agents fetched total=${allAgents.length} filtered=${agents.length}",
    );
    if (agents.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Agent bulunamadı.";
      });
      debugPrint("🧭 [OnboardingDemoChat] no agents -> error shown");
      return;
    }

    try {
      debugPrint(
        "🧭 [OnboardingDemoChat] startChat with agentId=${agents.first.id} onboardingFunnel=true",
      );
      await ref
          .read(AllControllers.agentsProfileViewController.notifier)
          .startChat(agents.first, onboardingFunnel: true);
      debugPrint("🧭 [OnboardingDemoChat] startChat completed");
    } catch (e) {
      debugPrint("❌ [OnboardingDemo] startChat error: $e");
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Sohbet başlatılamadı.";
      });
      debugPrint(
        "🧭 [OnboardingDemoChat] startChat failed -> stay on error (no Home)",
      );
      return;
    }
    if (!mounted) return;
    debugPrint(
      "🧭 [OnboardingDemoChat] flow done -> chat on stack; stop loader (no Home)",
    );
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return BackgroundWidget(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 14.h),
                Text(
                  "Sohbet hazırlanıyor...",
                  style: GoogleFonts.quicksand(color: Colors.white, fontSize: 16.sp),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            _error ?? "Yönlendiriliyor...",
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(color: Colors.white, fontSize: 16.sp),
          ),
        ),
      ),
    );
  }
}
