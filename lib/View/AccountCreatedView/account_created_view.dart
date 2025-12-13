import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/smooth_slide.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountCreatedView extends StatelessWidget {
  const AccountCreatedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
           Image.asset("assets/register4.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                      padding: EdgeInsets.only(bottom: 20,right: 15,left: 15),
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height / 1.5 ,
            decoration: BoxDecoration(
                 
              gradient: LinearGradient(colors: [Color(0xffAB10E2),Color(0xff3330FE).withValues(alpha: 0.0)],end: Alignment.topCenter,begin: Alignment.bottomCenter),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(40),topRight: Radius.circular(40))
            ),
              child: SafeArea(
                child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                      SmoothSlide(child: Text(Translate.translate(TranslateKeys.accountHasBeenCreated, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold),)),
                     SmoothSlide(child: Text(Translate.translate(TranslateKeys.accountCreatedSubtext, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 15.sp,fontWeight: FontWeight.w500),textAlign: TextAlign.center,)),
                     SizedBox(height: 40.h,),
                     MyButton(
                      onTap: () async{
             await  navigatorKey.currentState?.pushNamed('/bottomNavbar');
                      },
                      size: Size(MediaQuery.sizeOf(context).width, 50.h),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      radius: BorderRadius.circular(40).r,
                      child: Center(
                        child: Text(Translate.translate(TranslateKeys.next, context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600),),
                      ),
                     )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}