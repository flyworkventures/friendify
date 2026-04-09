import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Services/notification_service.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

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
    // Gerçek sistem izin durumunu kontrol et
    final hasPermission = await NotificationService.checkNotificationPermission();
    
    final prefs = await SharedPreferences.getInstance();
    final userPreference = prefs.getBool('notifications_enabled') ?? false;
    
    // Eğer kullanıcı bildirimleri açmak istiyor ama izin yoksa, izin verilmedi olarak göster
    final isEnabled = hasPermission && userPreference;
    
    setState(() {
      _notificationsEnabled = isEnabled;
    });
    
    debugPrint('📱 Notification permission status: $hasPermission, user preference: $userPreference, enabled: $isEnabled');
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Bildirimleri açmak istiyor - önce izin kontrolü yap
      final hasPermission = await NotificationService.checkNotificationPermission();
      
      if (!hasPermission) {
        // İzin yok, kullanıcıdan izin iste
        final granted = await NotificationService.requestNotificationPermission();
        
        if (!granted) {
          // İzin verilmedi, switch'i kapat ve kullanıcıya bilgi ver
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bildirim izni verilmedi. Lütfen ayarlardan izin verin.'),
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
    return Scaffold(
backgroundColor: Colors.transparent,
      body: Column(
        children: [
top(),
listTile(icon: SvgPicture.asset("assets/icons/user-edit.svg"), text: Translate.translate("profile_settings", context), onTap: ()async { navigatorKey.currentState?.pushNamed('/profileSettings');}),

//listTile(icon: SvgPicture.asset("assets/icons/user-edit.svg"), text: "Premium!", onTap: ()=> pushPremium()),
listTile(icon: SvgPicture.asset("assets/icons/profile.svg"), text: Translate.translate("share_with_friends", context), onTap: (){_showInviteDialog(context);}),

listTile(
  icon: SvgPicture.asset("assets/icons/notification-bing.svg"), 
  text: Translate.translate(TranslateKeys.notifications, context), 
  trailing: CupertinoSwitch(
    value: _notificationsEnabled,
    activeColor: Color(0xffA213E4),
    onChanged: _toggleNotifications,
  ),
  onTap: (){}
),

listTile(icon: SvgPicture.asset("assets/icons/medal-star.svg"), text: Translate.translate("rate_app", context), onTap: (){_rateApp();}),
listTile(icon: SvgPicture.asset("assets/icons/message-question.svg"), text: Translate.translate("faqs", context), onTap: (){navigatorKey.currentState?.pushNamed('/faqView');}),
listTile(icon: SvgPicture.asset("assets/icons/logout.svg",color: Colors.red,), text: Translate.translate("sign_out", context), onTap: (){_showLogoutDialog(context);},isLogout: true),
        ],
      ),
    );
  }
  Widget top(){
    return Container(
     width: MediaQuery.sizeOf(context).width,
     height: 300.h,
     decoration: BoxDecoration(
      
     ),
     child: Stack(
      children: [
        Container(
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
                    child: Container(
                      width: 86.w,
                      height: 86.h,
                      child: CachedNetworkImage(
                      imageUrl: ref.watch(AllControllers.userController)?.photoURL ?? "https://fakefriend.b-cdn.net/profile.png",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.person, size: 60),
                      ),
                    ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(ref.watch(AllControllers.userController)?.username ?? '',style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 20.sp),),
            
               ref.watch(AllControllers.userController)?.email.contains('@privaterelay.appleid.com') == true ? SizedBox.shrink() :  Text(ref.watch(AllControllers.userController)?.email ?? '',style: GoogleFonts.quicksand(color: Colors.white.withValues(alpha: 0.4),fontWeight: FontWeight.w600,fontSize: 13.sp),),
                  SizedBox(height: 6.h),
                  _buildSubscriptionBadge(ref.watch(AllControllers.userController)),
                ],
              ),
              )
          ],
         ),
        ),
   
      ],
     ),
    );
  }


pushPremium()async{
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
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
            ),
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
  
  await RevenueCatUI.presentPaywall(displayCloseButton: true);
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


Widget listTile({required Widget icon, required String text, Widget? trailing,required Function onTap, bool isLogout = false}){
  return ListTile(

    contentPadding: EdgeInsets.symmetric(horizontal: 15),
    onTap: ()=> onTap(),
    leading: Container(width: 38.w,height: 38.h,decoration: BoxDecoration(
      color: isLogout ? Colors.red.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8).r
    ),child: Center(child: icon,),),
    title: Text(text,style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 16.sp),),
    trailing: trailing ?? Icon(CupertinoIcons.chevron_right,color: Colors.white,),
  );
}

  /// Abonelik durumuna göre badge widget'ı oluşturur
  Widget _buildSubscriptionBadge(dynamic user) {
    if (user == null) {
      return SizedBox.shrink();
    }

    final activePremium = PremiumService.getActivePremium(user);

    String subscriptionText;
    Color backgroundColor;
    Color textColor;

    if (activePremium != null) {
      // Premium üye
      if (activePremium.type == PremiumType.paid) {
        subscriptionText = 'Premium';
        backgroundColor = Color(0xffA213E4); // Mor renk
        textColor = Colors.white;
      } else if (activePremium.type == PremiumType.freeTrial) {
        subscriptionText = 'Free Trial';
        backgroundColor = Color(0xffFFA500); // Turuncu renk
        textColor = Colors.white;
      } else {
        subscriptionText = 'Trial';
        backgroundColor = Color(0xffFFA500);
        textColor = Colors.white;
      }
    } else {
      // Premium değil
      subscriptionText = 'Free User';
      backgroundColor = Colors.grey; // Gri renk
      textColor = Colors.white;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        subscriptionText,
        style: GoogleFonts.quicksand(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 11.sp,
        ),
      ),
    );
  }



  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            Translate.translate("logout_dialog_title", context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
            ),
          ),
          content: Text(
            Translate.translate("logout_dialog_content", context),
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                Translate.translate("cancel", context),
                style: GoogleFonts.quicksand(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(AllControllers.profileSettingsViewController.notifier).logout();
              },
              child: Text(
                Translate.translate("sign_out", context),
                style: GoogleFonts.quicksand(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInviteDialog(BuildContext context) {
    final inviteLink = "https://friendifyapp.com/download/";

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Invite People",
                  style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 20.sp,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Copy the link to invite your friends",
                  style: GoogleFonts.quicksand(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: inviteLink));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Link copied to clipboard!'),
                                backgroundColor: Color(0xffA213E4),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Color(0xffF3E5F5),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(30.r),bottomLeft: Radius.circular(30.r)),
                          ),
                          child: Text(
                            inviteLink,
                            style: GoogleFonts.quicksand(
                              fontSize: 13.sp,
                              color: Color(0xffA213E4),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
             
                    Builder(
                      builder: (builderContext) {
                        return GestureDetector(
                          onTap: () async {
                            // Paylaş mesajı: "Gel ve yeni arkadaşlarımda tanış! $uygulamaLinki"
                            final shareMessage = "${Translate.translate("invite_message", context)} $inviteLink";
                            
                            // iOS için sharePositionOrigin gerekli (özellikle iPad için)
                            try {
                              final RenderBox? renderBox = builderContext.findRenderObject() as RenderBox?;
                              
                              if (renderBox != null && renderBox.hasSize) {
                                final position = renderBox.localToGlobal(Offset.zero) & renderBox.size;
                                // Pozisyon geçerli mi kontrol et
                                if (position.width > 0 && position.height > 0) {
                                  await Share.share(
                                    shareMessage,
                                    sharePositionOrigin: position,
                                  );
                                } else {
                                  // Geçersiz pozisyon, pozisyon olmadan paylaş
                                  await Share.share(shareMessage);
                                }
                              } else {
                                // RenderBox yok veya size yok, pozisyon olmadan paylaş
                                await Share.share(shareMessage);
                              }
                            } catch (e) {
                              // Hata durumunda pozisyon olmadan tekrar dene
                              debugPrint("Share error: $e");
                              if (mounted) {
                                await Share.share(shareMessage);
                              }
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: Color(0xffA213E4),
                              borderRadius: BorderRadius.only(topRight: Radius.circular(30.r),bottomRight: Radius.circular(30.r)),
                            ),
                            child: Text(
                              Translate.translate("share", context),
                              style: GoogleFonts.quicksand(
                                fontSize: 14.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
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
        url = "https://apps.apple.com/tr/app/friendify-ai-friends/id6755447367?l=tr";
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
              content: Text('Could not open app store'),
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
            content: Text('Error opening app store'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}