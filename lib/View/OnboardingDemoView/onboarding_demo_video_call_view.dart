import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingDemoVideoCallView extends StatefulWidget {
  const OnboardingDemoVideoCallView({super.key});

  @override
  State<OnboardingDemoVideoCallView> createState() =>
      _OnboardingDemoVideoCallViewState();
}

class _OnboardingDemoVideoCallViewState
    extends State<OnboardingDemoVideoCallView> {
  Timer? _sheetTimer;
  bool _sheetOpened = false;

  @override
  void initState() {
    super.initState();
    _sheetTimer = Timer(const Duration(minutes: 1), _openPaywallSheet);
  }

  @override
  void dispose() {
    _sheetTimer?.cancel();
    super.dispose();
  }

  Future<void> _openPaywallSheet() async {
    if (!mounted || _sheetOpened) return;
    _sheetOpened = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF3C1818),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  Translate.translate("video_gate_live_now", context),
                  style: GoogleFonts.quicksand(
                    color: const Color(0xFFFF6B6B),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                Translate.translate("video_gate_waiting_on_call", context),
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                Translate.translate("onboarding_demo_premium_desc", context),
                style: GoogleFonts.quicksand(
                  color: Colors.white70,
                  fontSize: 20.sp,
                ),
              ),
              SizedBox(height: 18.h),
              MyGradientButton(
                onTap: () async => _continueToLogin(action: "go_premium"),
                radius: BorderRadius.circular(30.r),
                size: Size(double.infinity, 50.h),
                child: Center(
                  child: Text(
                    Translate.translate(
                      "video_gate_answer_call_premium",
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Center(
                child: TextButton(
                  onPressed: () async =>
                      _continueToLogin(action: "continue_normal"),
                  child: Text(
                    Translate.translate("video_gate_not_now", context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white70,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _continueToLogin({required String action}) async {
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    await localService.setPostAuthAction(action);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 54.r,
                    backgroundColor: Colors.white10,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    "Emma",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 30.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    Translate.translate("onboarding_demo_connecting", context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white70,
                      fontSize: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
