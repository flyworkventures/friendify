import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Services/notification_service.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/View/PremiumScreen/premium_screen.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

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
      backgroundColor: Colors.white,
      body: Column(
        children: [
top(),
listTile(icon: HeroIcon(HeroIcons.user), text: Translate.translate("profile_settings", context), onTap: ()async { navigatorKey.currentState?.pushNamed('/profileSettings');}),
listTile(
  icon: HeroIcon(HeroIcons.bell), 
  text: Translate.translate(TranslateKeys.notifications, context), 
  trailing: CupertinoSwitch(
    value: _notificationsEnabled,
    activeColor: Color(0xffA213E4),
    onChanged: _toggleNotifications,
  ),
  onTap: (){}
),
listTile(icon: HeroIcon(HeroIcons.bolt), text: "Premium!", onTap: ()=> pushPremium()),
// listTile(icon: HeroIcon(HeroIcons.plus), text: Translate.translate("share_with_friends", context), onTap: (){}),
listTile(icon: HeroIcon(HeroIcons.questionMarkCircle), text: Translate.translate("faqs", context), onTap: (){navigatorKey.currentState?.pushNamed('/faqView');}),

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
              alignment: Alignment.topCenter,
              child: Container(
                width: MediaQuery.sizeOf(context).width,
                height: 145.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xffA213E4),Color(0xff2D30FF)],begin: Alignment.topLeft,end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30),bottomRight: Radius.circular(30))
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ClipOval(
                    child: Container(
                      width: 125.w,
                      height: 125.h,
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
                  Text(ref.watch(AllControllers.userController)?.username ?? '',style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w600,fontSize: 20.sp),),
            
                  SizedBox(height: 4.h),
               ref.watch(AllControllers.userController)?.email.contains('@privaterelay.appleid.com') == true ? SizedBox.shrink() :  Text(ref.watch(AllControllers.userController)?.email ?? '',style: GoogleFonts.quicksand(color: Colors.purple,fontWeight: FontWeight.w600,fontSize: 13.sp),),
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


Widget listTile({required Widget icon, required String text, Widget? trailing,required Function onTap}){
  return ListTile(

    contentPadding: EdgeInsets.symmetric(horizontal: 30),
    onTap: ()=> onTap(),
    leading: ClipOval(child: Container(width: 32.w,height: 32.h,color: Color(0xffF4F4F4),child: Center(child: icon,),)),
    title: Text(text,style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w500,fontSize: 14.sp),),
    trailing: trailing ?? Icon(CupertinoIcons.chevron_right,color: Colors.black,),
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
      subscriptionText = 'Free';
      backgroundColor = Color(0xffE0E0E0); // Gri renk
      textColor = Color(0xff666666);
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


}