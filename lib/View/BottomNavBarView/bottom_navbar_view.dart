
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Services/notification_service.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/View/BottomNavBarView/bottom_nav_bar.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:ionicons/ionicons.dart';
import 'package:responsive_navigation_bar/responsive_navigation_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class BottomNavbarView extends ConsumerStatefulWidget {
  const BottomNavbarView({super.key});

  @override
  ConsumerState<BottomNavbarView> createState() => _BottomNavbarViewState();
}

class _BottomNavbarViewState extends ConsumerState<BottomNavbarView> {
  bool _permissionDialogShown = false; // Dialog'un gösterilip gösterilmediğini takip et

  @override
  void initState() {
    super.initState();
    // Widget tree build edildikten sonra bildirim izni kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    // Eğer dialog zaten gösterildiyse, tekrar gösterme
    if (_permissionDialogShown) {
      return;
    }

    // Daha önce izin sorulmuş mu kontrol et
    final hasAskedBefore = await NotificationService.hasAskedPermissionBefore();
    
    // Eğer daha önce sorulmuşsa, tekrar sorma (Apple kuralı)
    if (hasAskedBefore) {
      _permissionDialogShown = true; // Flag'i set et
      return;
    }

    // Kullanıcıya izin isteme nedeni açıklayan dialog göster (Apple kuralı)
    if (!mounted) return;
    
    // Dialog'u gösterildi olarak işaretle
    _permissionDialogShown = true;
    
    // Dialog'u bir süre beklemeden göster (kullanıcının ekranı görmesi için)
    await Future.delayed(Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            Translate.translate(TranslateKeys.notificationPermissionTitle, context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
            ),
          ),
          content: Text(
            Translate.translate(TranslateKeys.notificationPermissionMessage, context),
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Kullanıcı "Şimdi Değil" dedi, izin isteme ama flag'i işaretle ki tekrar sormasın
                await NotificationService.markPermissionAsked();
              },
              child: Text(
                Translate.translate(TranslateKeys.notNow, context),
                style: GoogleFonts.quicksand(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Kullanıcı "İzin Ver" dedi, izin iste
                final granted = await NotificationService.requestNotificationPermission();
                
                // İzin verildiyse bildirimleri başlat
                if (granted) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', true);
                  await NotificationService.startPeriodicNotifications();
                  debugPrint('✅ Notification permission granted, notifications started');
                } else {
                  debugPrint('⚠️ Notification permission not granted');
                }
              },
              child: Text(
                Translate.translate(TranslateKeys.enableNotifications, context),
                style: GoogleFonts.quicksand(
                  color: MyColors.purple,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      extendBody: true,
      body: BackgroundWidget(
        child: Stack(
          children: [
            ref.read(AllControllers.bottomNavbarController.notifier).pages[ref.watch(AllControllers.bottomNavbarController).currentIndex],
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MyBottomNavBar(
        
                  currentIndex: ref.watch(AllControllers.bottomNavbarController).currentIndex,
                  items: [
                    MyBottomNavBarItem(icon: "assets/icons/home.svg",onTap: () => ref.read(AllControllers.bottomNavbarController.notifier).updateIndex(0),),
                    MyBottomNavBarItem(icon: "assets/icons/ai-users.svg",onTap: () => ref.read(AllControllers.bottomNavbarController.notifier).updateIndex(1),),
                    MyBottomNavBarItem(icon: "assets/icons/messages-2.svg",onTap: () => ref.read(AllControllers.bottomNavbarController.notifier).updateIndex(2),),
                    MyBottomNavBarItem(icon: "assets/icons/user.svg",onTap: () => ref.read(AllControllers.bottomNavbarController.notifier).updateIndex(3),),
                  ],
                  width: MediaQuery.sizeOf(context).width)
              ),
            )
          ],
        ),
      ),
    );
  }
}