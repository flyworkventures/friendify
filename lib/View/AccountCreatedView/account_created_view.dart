import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/smooth_slide.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kayıt sonrası: 4 adım saf UI (her biri 1 sn), ardından onboarding akışına devam.
class AccountCreatedView extends ConsumerStatefulWidget {
  const AccountCreatedView({super.key});

  @override
  ConsumerState<AccountCreatedView> createState() => _AccountCreatedViewState();
}

class _AccountCreatedViewState extends ConsumerState<AccountCreatedView> {
  static final _stepKeys = <String>[
    TranslateKeys.accountSetupStepInterests,
    TranslateKeys.accountSetupStepHabits,
    TranslateKeys.accountSetupStepPlan,
    TranslateKeys.accountSetupStepContent,
  ];

  Timer? _stepTimer;
  int _completedSteps = 0;
  bool _isCompletingFlow = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🧭 [AccountCreated] initState");
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _completedSteps++);
      debugPrint("🧭 [AccountCreated] progress step=$_completedSteps");
      if (_completedSteps >= 4) {
        t.cancel();
        _stepTimer = null;
        debugPrint("🧭 [AccountCreated] progress done -> _completeAccountFlow");
        _completeAccountFlow();
      }
    });
  }

  Future<void> _completeAccountFlow() async {
    if (_isCompletingFlow || !mounted) {
      debugPrint(
        "🧭 [AccountCreated] skip _completeAccountFlow isCompleting=$_isCompletingFlow mounted=$mounted",
      );
      return;
    }
    _isCompletingFlow = true;
    debugPrint("🧭 [AccountCreated] _completeAccountFlow started");
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final pendingAuth = localService.getOnboardingPendingAuth();
    debugPrint(
      "🧭 [AccountCreated] pendingAuth exists=${pendingAuth != null} data=${pendingAuth?.toString()}",
    );

    if (pendingAuth != null) {
      final email = pendingAuth["email"]?.toString().trim() ?? "";
      final credential = pendingAuth["credential"]?.toString().trim() ?? "";
      final fallbackUsername = pendingAuth["fallbackUsername"]?.toString();
      debugPrint(
        "🧭 [AccountCreated] pendingAuth parsed email=$email credential=$credential fallbackUsername=$fallbackUsername",
      );
      if (email.isNotEmpty && credential.isNotEmpty) {
        final registerNotifier = ref.read(
          AllControllers.registerViewController.notifier,
        );
        debugPrint("🧭 [AccountCreated] hydrateFromLocalAnswers starting");
        await registerNotifier.hydrateFromLocalAnswers(
          email: email,
          credential: credential,
          fallbackUsername: fallbackUsername,
        );
        if (credential == "apple") {
          final appleUserIdentifier =
              pendingAuth["appleUserIdentifier"]?.toString().trim() ?? "";
          final appleToken =
              pendingAuth["appleToken"]?.toString().trim() ?? "";
          if (appleUserIdentifier.isNotEmpty) {
            registerNotifier.updateAppleUserIdentifier(appleUserIdentifier);
          }
          if (appleToken.isNotEmpty) {
            registerNotifier.updateAppleToken(appleToken);
          }
        }
        debugPrint("🧭 [AccountCreated] createUser starting");
        final created = await registerNotifier.createUser();
        debugPrint("🧭 [AccountCreated] createUser result=$created");
        if (!created) {
          _isCompletingFlow = false;
          debugPrint("🧭 [AccountCreated] createUser failed -> stay on page");
          return;
        }
      }
      await localService.clearOnboardingPendingAuth();
      debugPrint("🧭 [AccountCreated] pendingAuth cleared");
    } else {
      debugPrint(
        "🧭 [AccountCreated] no pendingAuth (Onboard->Register only): "
        "createUser skipped here; OnboardingDemoChat will guestLogin for token",
      );
    }

    if (!mounted) return;
    debugPrint("🧭 [AccountCreated] navigating -> /onboardingDemoChatView");
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/onboardingDemoChatView',
      (route) => false,
    );
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutedPurple = const Color(0xFF2D1B4E);
    final canContinue = _completedSteps >= 4 && !_isCompletingFlow;

    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: Padding(
            padding:  EdgeInsets.only(top: 40).r,
            child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.center,
              children: [
               SmoothSlide(
                            child: Text(
                              Translate.translate(TranslateKeys.accountCreationProgressTitle, context),
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          SmoothSlide(
                            child: Text(
                              Translate.translate(TranslateKeys.accountCreationProgressSubtitle, context),
                              style: GoogleFonts.quicksand(
                                color: Color(0xffD1D5DC),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 40.h),


                            Expanded(
                            child: ListView.separated(
                              itemCount: 4,
                              physics: NeverScrollableScrollPhysics(),
                              separatorBuilder: (_, __) => SizedBox(height: 16.h),
                              itemBuilder: (context, index) => _buildStepRow(context, index),
                            ),
                          ),
          Opacity(
                            opacity: canContinue ? 1 : 0.5,
                            child: AbsorbPointer(
                              absorbing: !canContinue,
                              child: canContinue
                                      ? MyGradientButton(
                                          onTap: _completeAccountFlow,
                                          size: Size(MediaQuery.sizeOf(context).width, 50.h),
                                          margin: EdgeInsets.symmetric(horizontal: 16.w),
                                          radius: BorderRadius.circular(40).r,
                                          child: Center(
                                            child: Text(
                                              Translate.translate(TranslateKeys.accountGetStarted, context),
                                              style: GoogleFonts.quicksand(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16.sp,
                                              ),
                                            ),
                                          ),
                                        )
                                      : MyButton(
                                          onTap: null,
                                          size: Size(MediaQuery.sizeOf(context).width, 50.h),
                                          backgroundColor: mutedPurple,
                                          radius: BorderRadius.circular(40).r,
                                          child: Center(
                                            child: Text(
                                              Translate.translate(TranslateKeys.accountGetStarted, context),
                                              style: GoogleFonts.quicksand(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                            ),
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, int index) {
    final done = index < _completedSteps;
    final loading = !done && index == _completedSteps && _completedSteps < 4;

    Widget leading;
    if (done) {
      leading = Icon(Icons.verified_outlined, color: Color(0xffAB10E2), size: 24.sp);
    } else if (loading) {
      leading = SizedBox(
        width: 28.w,
        height: 28.w,
        child: CircularProgressIndicator(
          strokeWidth: 1,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      );
    } else {
      leading = Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading,
        SizedBox(width: 14.w),
        Text(
          Translate.translate(_stepKeys[index], context),
          style: GoogleFonts.quicksand(
            color:  Colors.white.withValues(alpha: done ? 1 : 0.4),
            fontSize: 14.sp,
            fontWeight: done ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
