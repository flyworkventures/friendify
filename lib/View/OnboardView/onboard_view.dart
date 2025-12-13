
import 'dart:async';
import 'dart:io';

import 'package:cross_fade/cross_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/smooth_slide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:substring_highlight/substring_highlight.dart';
import 'package:url_launcher/url_launcher.dart';


class OnboardView extends ConsumerStatefulWidget {
  const OnboardView({super.key});

  @override
  ConsumerState<OnboardView> createState() => OnboardViewState();
}

class OnboardViewState extends ConsumerState<OnboardView> {


  final titleTextStyle =  GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold);
   final List<String> images = [
    'assets/onboard1.png',
    'assets/onboard2.png',
    'assets/onboard3.png',
  ];


  int currentIndex = 0;
  bool showFirst = true;
  bool isTransitioning = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
   timer = Timer.periodic(Duration(seconds: 5), (a){
      setState(() {
        if (currentIndex == 2) {
          currentIndex = 0;
        }else{
              currentIndex++;
        }
    
        debugPrint("Index: $currentIndex");
      });
    });

  //  _startLoop();
  }
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
  
  /*
  void _startLoop() async {
    while (mounted) {
      // 5 saniye göster
      await Future.delayed(const Duration(seconds: 5));

      if (!mounted) return;

      // Fade başlasın
      setState(() {
        showFirst = !showFirst;
      });

      // Fade tamamlanınca index değişsin
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Sadece bir kez index değiştir
      setState(() {
        currentIndex = (currentIndex + 1) % images.length;
      });
    }
  }

  */
  List<Widget> getTitles(BuildContext context) {
    return [
       SmoothSlide(
              child: Text(Translate.translate("chat_like_real", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold,),textAlign: TextAlign.center,)
              ),
                     SmoothSlide(
              child: Text(Translate.translate("choose_friends_mood", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold),textAlign: TextAlign.center,)
              ),
                     SmoothSlide(
              child: Text(Translate.translate("not_just_listening", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold),textAlign: TextAlign.center,)
              ),
    ];
  }

  List<Widget> getSubtitles(BuildContext context) {
    return [
     SmoothSlide(
              child: Text(Translate.translate("discover_ai", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
              ),
                  SmoothSlide(
              child: Text(Translate.translate("cheerful_calm", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
              ),
                  SmoothSlide(
              child: Text(Translate.translate("ai_analyzes", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
              ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final titles = getTitles(context);
    final subtitles = getSubtitles(context);
    
    return Scaffold(
      body: Stack(
     
        children: [
          /*
          AnimatedCrossFade(
            duration: const Duration(seconds: 1),
            crossFadeState:
                showFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Image.asset(
              images[currentIndex],
              fit: BoxFit.cover,
            ),
            secondChild: Image.asset(
              images[currentIndex++ == 3 ? 0 : currentIndex],
              fit: BoxFit.cover,
            ),
            layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(key: bottomKey, child: bottomChild),
                  Positioned.fill(key: topKey, child: topChild),
                ],
              );
            },
          ),
*/
       CrossFade(value: currentIndex, builder: (context,index)=> Image.asset("assets/onboard$index.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover,),),


      //  Image.asset("assets/onboard1.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover,),
        bottom()
        ],
      ),
    );
  }
  Widget bottom(){
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.only(bottom: 20),
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height / 1.7,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xffAB10E2),Color(0xff3330FE).withValues(alpha: 0.0)],end: Alignment.topCenter,begin: Alignment.bottomCenter),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(40),topRight: Radius.circular(40))
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
             getTitles(context)[currentIndex],
             getSubtitles(context)[currentIndex],
                
              SizedBox(height: 20.h,),


  if(Platform.isIOS)...[

               MyButton(
                onTap: ()async{
                         debugPrint("🍎 Apple button clicked");
          await ref.read(AllControllers.onboardViewController.notifier).appleAuth();
    
                },
                margin: EdgeInsets.symmetric(horizontal: 20),
                radius: BorderRadius.circular(50),
                backgroundColor: Colors.black,
                
                size:Size(300.w, 50.h),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    SvgPicture.asset("assets/apple.svg",color: Colors.white,width: 22.w,),
                   
                      Text(Translate.translate("continue_with_apple", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w500),),
                        SizedBox.shrink(),
                    
                  
                    ],
                  ),
                ),
              ),

               SizedBox(height: 20.h,),

    

        // Misafir giriş butonu
               MyButton(
                onTap: () async {
                  debugPrint("👤 Guest button clicked");
                  await ref.read(AllControllers.onboardViewController.notifier).guestLogin();
                },
                margin: EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
                radius: BorderRadius.circular(50),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                size: Size(250.w, 45.h),
                child: Center(
                  child: Text(
                    Translate.translate("continue_as_guest", context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

    socialAuthAreaIOS()
  ],



  if(Platform.isAndroid)...[

               MyButton(
                onTap: (){



                  ref.read(AllControllers.onboardViewController.notifier).googleAuth();
                },
                margin: EdgeInsets.symmetric(horizontal: 20),
                radius: BorderRadius.circular(50),
                backgroundColor: Colors.white,
                size:Size(MediaQuery.sizeOf(context).width, 50.h),
                child: Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Image.asset("assets/google.png",width: 30.w,),
                      SizedBox(width: 10.h,),
                      Text(Translate.translate("continue_with_google", context),style: GoogleFonts.quicksand(color: Colors.black,fontSize: 14.sp,fontWeight: FontWeight.w500),),
                     
                    

                    ],
                  ),
                ),
              ),


               SizedBox(height: 20.h,),


    socialAuthAreaAndroid()
  ],


  SizedBox(height: 20.h,),

  GestureDetector(
    onTap: () async{
     await launchUrl(Uri.parse("https://fly-work.com/friendify/terms/"));
    },
    child: SubstringHighlight(
          text: Translate.translate("terms_signup_text", context),
          term: Translate.translate("terms_signup_highlight", context),
          textAlign: TextAlign.center,
          textStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w400,fontSize: 12.sp),
          textStyleHighlight: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,decoration: TextDecoration.underline,fontSize: 12.sp),
        ),
  ),
        GestureDetector(
              onTap: () async{
    await  launchUrl(Uri.parse("https://fly-work.com/friendify/privacy-policy/"));
    },
          child: SubstringHighlight(
          text: Translate.translate("privacy_data_text", context),
          term: Translate.translate("privacy_data_highlight", context),
          textAlign: TextAlign.center,
          textStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w400,fontSize: 12.sp),
          textStyleHighlight: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,decoration: TextDecoration.underline,fontSize: 12.sp),
                ),
        ),
          ],
        ),
      ),
    );
  }

  Widget socialAuthAreaAndroid(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        /*
        socialButton(onTap: (){}, child: Center(child: Image.asset("assets/google.png",width: 20.w,),), backgroundColor: Colors.white),
        SizedBox(width: 15.w,),
        */
        socialButton(onTap: () async{
          debugPrint("🔵 Facebook button clicked");
         
           await ref.read(AllControllers.onboardViewController.notifier).facebookAuth();
          
          debugPrint("🔵 Facebook auth completed");
        }, child: Center(child: SvgPicture.asset("assets/facebook.svg"),), backgroundColor: Color(0xff1877F2)),
        SizedBox(width: 15.w,),
        socialButton(onTap: () async{
          debugPrint("🍎 Apple button clicked");
          await ref.read(AllControllers.onboardViewController.notifier).appleAuth();
          debugPrint("🍎 Apple auth completed");
        }, child: Center(child: SvgPicture.asset("assets/apple.svg",color: Colors.white,width: 18.w,),), backgroundColor: Colors.black)
      ],
    );
  }



  Widget socialAuthAreaIOS(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        /*
        socialButton(onTap: (){}, child: Center(child: Image.asset("assets/google.png",width: 20.w,),), backgroundColor: Colors.white),
        SizedBox(width: 15.w,),
        */
        socialButton(onTap: () async{
          debugPrint("🔵 Facebook button clicked");
         
           await ref.read(AllControllers.onboardViewController.notifier).facebookAuth();
          
          debugPrint("🔵 Facebook auth completed");
        }, child: Center(child: SvgPicture.asset("assets/facebook.svg"),), backgroundColor: Color(0xff1877F2)),
        SizedBox(width: 15.w,),
        socialButton(onTap: () async{
    ref.read(AllControllers.onboardViewController.notifier).googleAuth();
        }, child: Center(child: Image.asset("assets/google.png",width: 24.w,),), backgroundColor: Colors.white)
      ],
    );
  }



Widget socialButton({required Function() onTap,required Widget child,required Color backgroundColor}){
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 45.w,
      height: 45.h,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Center(
        child: child,
      ),
    ),
  );
}
}

