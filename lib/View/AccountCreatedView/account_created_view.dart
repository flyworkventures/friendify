import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/smooth_slide.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kayıt sonrası: 4 adım saf UI (her biri 1 sn), ardından [RegisterViewController.createUser] (hoş geldin dahil).
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
  bool _signupStarted = false;
  bool _signupBusy = false;
  bool _signupOk = false;

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _completedSteps++);
      if (_completedSteps >= 4) {
        t.cancel();
        _stepTimer = null;
        _kickOffSignup();
      }
    });
  }

  void _kickOffSignup() {
    if (_signupStarted) return;
    _signupStarted = true;
    _runSignup();
  }

  Future<void> _runSignup() async {
    if (!mounted) return;
    setState(() {
      _signupBusy = true;
      _signupOk = false;
    });
    final ok = await ref.read(AllControllers.registerViewController.notifier).createUser();
    if (!mounted) return;
    setState(() {
      _signupBusy = false;
      _signupOk = ok;
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Translate.translate(TranslateKeys.accountCreationSignupFailed, context)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutedPurple = const Color(0xFF2D1B4E);
    final canContinue = _signupOk && !_signupBusy;
    final showRetry = !_signupBusy && _signupStarted && !_signupOk && _completedSteps >= 4;

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
                          if (showRetry) ...[
                            SizedBox(height: 8.h),
                            Center(
                              child: TextButton(
                                onPressed: _runSignup,
                                child: Text(
                                  Translate.translate(TranslateKeys.retry, context),
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.sp,
                                  ),
                                ),
                              ),
                            ),
                          ],


          Opacity(
                            opacity: canContinue ? 1 : 0.5,
                            child: AbsorbPointer(
                              absorbing: !canContinue || _signupBusy,
                              child: _signupBusy
                                  ? MyButton(
                                      onTap: null,
                                      size: Size(MediaQuery.sizeOf(context).width, 50.h),
                                      backgroundColor: mutedPurple,
                                      radius: BorderRadius.circular(40).r,
                                      child: Center(
                                        child: SizedBox(
                                          width: 24.w,
                                          height: 24.w,
                                          child: const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    )
                                  : canContinue
                                      ? MyGradientButton(
                                          onTap: () {
                                            navigatorKey.currentState?.pushNamedAndRemoveUntil(
                                              '/bottomNavbar',
                                              (route) => false,
                                            );
                                          },
                                          size: Size(MediaQuery.sizeOf(context).width, 50.h),
                                          margin: EdgeInsets.zero,
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
