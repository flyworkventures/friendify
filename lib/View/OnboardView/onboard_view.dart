
import 'dart:async';
import 'dart:ui';

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
import 'package:smooth_page_indicator/smooth_page_indicator.dart';


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
              child: Text(Translate.translate("onboard_title_1", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 24.sp,fontWeight: FontWeight.bold,),textAlign: TextAlign.center,)
              ),     
              

                     SmoothSlide(
              child: Text(Translate.translate("onboard_title_2", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 24.sp,fontWeight: FontWeight.bold,),textAlign: TextAlign.center,)
              ),    


                              SmoothSlide(
                                   child: Text(Translate.translate("onboard_title_3", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 24.sp,fontWeight: FontWeight.bold),textAlign: TextAlign.center,)
                                   ),
    ];
  }

  List<Widget> getSubtitles(BuildContext context) {
    return [
     SmoothSlide(
              child: Text(Translate.translate("onboard_subtitle_1", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
              ),
                  SmoothSlide(
                                child: Text(Translate.translate("onboard_subtitle_2", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
                                ),
                  SmoothSlide(
                                child: Text(Translate.translate("onboard_subtitle_3", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
                                ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
     
        children: [
 
       CrossFade(value: currentIndex, builder: (context,index)=> Image.asset("assets/onboard$index.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover,),),


      //  Image.asset("assets/onboard1.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover,),
        bottom(currentIndex)
        ],
      ),
    );
  }
  Widget bottom(int index){
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20,right: 20,left: 20).r,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16).r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10,sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10,vertical: 15),
              width: MediaQuery.sizeOf(context).width,
              height: 211.h,
              decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16).r,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2))
              ),
              child: Column(
     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      AnimatedSmoothIndicator(
                    effect: ExpandingDotsEffect(spacing: 4,dotWidth: 10.w,dotHeight: 3.h,dotColor: Color(0xffD9D9D9),activeDotColor: Color(0xffAB10E2)),
                    activeIndex: index,count: 3),
                    SizedBox(height: 10.h,),
                  getTitles(context)[currentIndex],
                                     getSubtitles(context)[currentIndex]  ,
         
                    ],
                  ),
                    MyGradientButton(
                      radius: BorderRadius.circular(40),
                      size: Size(358.w, 48.h),
                      child: Center(
                        child: Text(Translate.translate("onboard_cta", context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w700,fontSize: 20.sp),),
                      ),
                      onTap: () {
                        Navigator.pushNamedAndRemoveUntil(context, "/login", (a)=>false);
                      },
                    )

            /*
            
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
            
                        MyButton(
                      onTap: () async {
                        debugPrint("👤 Guest button clicked");
                        await ref.read(AllControllers.onboardViewController.notifier).guestLogin();
                      },
                      margin: EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
                      radius: BorderRadius.circular(50),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      size: Size(500.w, 45.h),
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
            
            
            
                     SizedBox(height: 5.h,),
            
            
                socialAuthAreaAndroid()
              ],
              */
            
            
             
            /*
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
              */
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

