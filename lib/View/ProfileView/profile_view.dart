import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/notification_service.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/future_progress_dialog.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:heroicons/heroicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:friendfy/Services/paywall_presentation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final hasPermission =
        await NotificationService.checkNotificationPermission();

    final prefs = await SharedPreferences.getInstance();

    if (hasPermission) {
      // Sistem izni varsa, SharedPreferences'ı da senkronize et
      await prefs.setBool('notifications_enabled', true);
    }

    final isEnabled = hasPermission;

    setState(() {
      _notificationsEnabled = isEnabled;
    });

    debugPrint(
      '📱 Notification permission status: $hasPermission, enabled: $isEnabled',
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Bildirimleri açmak istiyor - önce izin kontrolü yap
      final hasPermission =
          await NotificationService.checkNotificationPermission();

      if (!hasPermission) {
        // İzin yok, kullanıcıdan izin iste
        final granted =
            await NotificationService.requestNotificationPermission();

        if (!granted) {
          // İzin verilmedi, switch'i kapat ve kullanıcıya bilgi ver
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  Translate.translate(
                    "profile_notification_permission_denied",
                    context,
                  ),
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          setState(() {
            _notificationsEnabled = false;
          });
          return;
        }
      }

      // İzin var, bildirimleri başlat
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);

      setState(() {
        _notificationsEnabled = true;
      });

      await NotificationService.startPeriodicNotifications();
      debugPrint('✅ Notifications enabled');
    } else {
      // Bildirimleri kapat
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);

      setState(() {
        _notificationsEnabled = false;
      });

      await NotificationService.stopPeriodicNotifications();
      debugPrint('❌ Notifications disabled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(AllControllers.userController);
    final showPremiumPlanCta = !PremiumService.isPremiumActive(user);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        padding: EdgeInsets.only(bottom: 120).r,
        child: Column(
          children: [
            top(),
            if (showPremiumPlanCta) buildPremiumWidget(),
            SizedBox(height: 20.h),
            listTile(
              icon: SvgPicture.asset("assets/icons/user-edit.svg", width: 24),
              text: Translate.translate("profile_settings", context),
              onTap: () async {
                navigatorKey.currentState?.pushNamed('/profileSettings');
              },
            ),

            //listTile(icon: SvgPicture.asset("assets/icons/user-edit.svg"), text: "Premium!", onTap: ()=> pushPremium()),
            listTile(
              icon: SvgPicture.asset("assets/icons/profile.svg", width: 24),
              text: Translate.translate("share_with_friends", context),
              onTap: () {
                _showInviteDialog(context);
              },
            ),
            listTile(
              icon: Icon(CupertinoIcons.globe, color: Colors.white),
              text: Translate.translate(TranslateKeys.language, context),
              onTap: () {
                navigatorKey.currentState?.pushNamed('/languageView');
              },
            ),

            listTile(
              icon: SvgPicture.asset("assets/icons/notification-bing.svg"),
              text: Translate.translate(TranslateKeys.notifications, context),
              trailing: CupertinoSwitch(
                value: _notificationsEnabled,
                activeTrackColor: Color(0xffA213E4),
                onChanged: _toggleNotifications,
              ),
              onTap: () {},
            ),

            listTile(
              icon: SvgPicture.asset("assets/icons/medal-star.svg"),
              text: Translate.translate("rate_app", context),
              onTap: () {
                _rateApp();
              },
            ),
            listTile(
              icon: SvgPicture.asset("assets/icons/message-question.svg"),
              text: Translate.translate("faqs", context),
              onTap: () {
                navigatorKey.currentState?.pushNamed('/faqView');
              },
            ),
            listTile(
              icon: SvgPicture.asset(
                "assets/icons/logout.svg",
                color: Colors.red,
              ),
              text: Translate.translate("sign_out", context),
              onTap: () {
                _showLogoutDialog(context);
              },
              isLogout: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget top() {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: 300.h,
      decoration: BoxDecoration(),
      child: Stack(
        children: [
          SizedBox(
            height: 270.h,
            width: MediaQuery.sizeOf(context).width,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 86.w,
                          height: 86.w,
                          child: CachedNetworkImage(
                            imageUrl:
                                ref
                                    .watch(AllControllers.userController)
                                    ?.photoURL ??
                                "https://fakefriend.b-cdn.net/app/Group%201174.png",
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.person, size: 60),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        ref.watch(AllControllers.userController)?.username ??
                            '',
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 20.sp,
                        ),
                      ),

                      ref
                                  .watch(AllControllers.userController)
                                  ?.email
                                  .contains('@privaterelay.appleid.com') ==
                              true
                          ? SizedBox.shrink()
                          : Text(
                              ref.watch(AllControllers.userController)?.email ??
                                  '',
                              style: GoogleFonts.quicksand(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                      SizedBox(height: 6.h),
                      _buildSubscriptionBadge(
                        ref.watch(AllControllers.userController),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pushPremium() async {
    // Misafir kullanıcı kontrolü
    UserModel? user = ref.read(AllControllers.userController);
    if (user?.credential == "guest") {
      // Misafir kullanıcı için uyarı dialog göster
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Text(
              Translate.translate("login_required_title", context),
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w700,
                fontSize: 18.sp,
              ),
            ),
            content: Text(
              Translate.translate("login_required_message", context),
              style: GoogleFonts.quicksand(fontSize: 14.sp),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Oturum açma sayfasına yönlendir
                  navigatorKey.currentState?.pushNamed('/onboard');
                },
                child: Text(
                  Translate.translate("ok", context),
                  style: GoogleFonts.quicksand(
                    color: Color(0xffA213E4),
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    await PaywallPresentation.present(context, displayCloseButton: true);
    /*
  Navigator.of(context).push(
  PageRouteBuilder(
    transitionDuration: Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => PremiumScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0); // alttan başla
      const end = Offset.zero;         // ekrana gelsin
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
);

*/
  }

  Widget buildPremiumWidget() {
    return GestureDetector(
      onTap: () {
        pushPremium();
      },
      child: Container(
        height: 76.h,
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 20).r,
        padding: EdgeInsets.symmetric(horizontal: 20).r,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/icons/gecis.png"),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(16).r,
          border: GradientBoxBorder(
            gradient: LinearGradient(
              colors: [
                Color(0xff3E0951).withValues(alpha: 0.1),
                Color(0xffFFC107),
              ],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Image.asset("assets/icons/king.png", width: 53.w),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      Translate.translate(
                        "profile_premium_banner_title",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            MyGradientButton(
              colors: [Color(0xffE1A903), Color(0xffC67A00)],
              size: Size(120.w, 32.h),
              onTap: () => pushPremium(),
              radius: BorderRadius.circular(40).r,
              child: Center(
                child: Text(
                  Translate.translate("upgrade_plan", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget listTile({
    required Widget icon,
    required String text,
    Widget? trailing,
    required Function onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 15),
      onTap: () => onTap(),
      leading: Container(
        width: 38.w,
        height: 36.h,

        decoration: BoxDecoration(
          color: isLogout
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8).r,
        ),
        child: Center(
          child: SizedBox(width: 24.w, height: 24.h, child: icon),
        ),
      ),
      title: Text(
        text,
        style: GoogleFonts.quicksand(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16.sp,
        ),
      ),
      trailing:
          trailing ?? Icon(CupertinoIcons.chevron_right, color: Colors.white),
    );
  }

  /// Abonelik durumuna göre badge widget'ı oluşturur
  Widget _buildSubscriptionBadge(dynamic user) {
    if (user == null) {
      return SizedBox.shrink();
    }

    final activePremium = PremiumService.getActivePremium(user);
    final isPaidPremium =
        activePremium != null && activePremium.type == PremiumType.paid;

    String subscriptionText;
    Color textColor = Colors.white;

    if (isPaidPremium) {
      subscriptionText = Translate.translate("profile_badge_premium", context);
    } else {
      subscriptionText = Translate.translate(
        "profile_badge_free_user",
        context,
      );
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(minHeight: 30.h),
        padding: EdgeInsets.symmetric(
          horizontal: isPaidPremium ? 10.w : 14.w,
          vertical: 6.h,
        ),
        decoration: BoxDecoration(
          color: isPaidPremium ? Color(0xffFFA500) : Colors.grey,
          borderRadius: BorderRadius.circular(20.r),
          gradient: isPaidPremium
              ? LinearGradient(colors: [Color(0xffE1A903), Color(0xffC67A00)])
              : null,
        ),
        child: isPaidPremium
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset("assets/icons/king.png", width: 22.w),
                  SizedBox(width: 4.w),
                  Text(
                    subscriptionText,
                    style: GoogleFonts.quicksand(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                      height: 1.1,
                    ),
                  ),
                ],
              )
            : Text(
                subscriptionText,
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15.sp,
                  height: 1.1,
                ),
              ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.76;
        return SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22.r),
              topRight: Radius.circular(22.r),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                color: const Color(0xFF050505).withValues(alpha: 0.94),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    Container(
                      width: 46.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Container(
                      width: 54.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44336).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          "assets/icons/logout.svg",
                          width: 24.w,
                          height: 24.h,
                          color: Color(0xffF44336),
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18.w),
                      child: Text(
                        Translate.translate("logout_dialog_content", context),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),

                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 20.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40.h,
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCE64FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  Translate.translate("cancel", context),
                                  style: GoogleFonts.quicksand(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),

                          Expanded(
                            child: SizedBox(
                              height: 40.h,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  context.runWithProgressDialog(
                                    () => ref
                                        .read(
                                          AllControllers
                                              .profileSettingsViewController
                                              .notifier,
                                        )
                                        .logout(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9B9B9B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  Translate.translate("sign_out", context),
                                  style: GoogleFonts.quicksand(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInviteDialog(BuildContext context) {
    final inviteLink = "https://fly-work.com/friendify/download/";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          margin: EdgeInsets.only(left: 12.w, right: 12.w, bottom: 20.h),
          padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
          decoration: BoxDecoration(
            color: const Color(0xff050505),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  Translate.translate("share_with_friends", context),
                  style: GoogleFonts.quicksand(
                    fontSize: 34.sp * 0.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Container(
                height: 58.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.link,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        inviteLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: inviteLink),
                        );
                        if (!mounted) return;
                        Navigator.of(sheetContext).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xff070707),
                              elevation: 0,
                              duration: const Duration(seconds: 2),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.r),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: const Color(0xff34C759),
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Text(
                                      Translate.translate(
                                        "profile_link_copied",
                                        context,
                                      ),
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        });
                      },
                      child: HeroIcon(
                        HeroIcons.clipboard,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6.h),
            ],
          ),
        );
      },
    );
  }

  /// Uygulamayı App Store veya Play Store'da değerlendirmeye yönlendir
  Future<void> _rateApp() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String appId = packageInfo.packageName;

      String url;
      if (Platform.isIOS) {
        // iOS App Store URL'i (app ID ile)
        // Gerçek App Store ID'nizi buraya eklemelisiniz
        url =
            "https://apps.apple.com/tr/app/friendify-ai-friends/id6755447367?l=tr";
        // Eğer App Store ID'niz varsa direkt kullanabilirsiniz:
        // url = "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review";
      } else if (Platform.isAndroid) {
        // Android Play Store URL'i
        url = "https://play.google.com/store/apps/details?id=$appId";
      } else {
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Translate.translate("profile_could_not_open_store", context),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error opening app store: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Translate.translate("profile_error_opening_store", context),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
