import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';

class StartView extends StatelessWidget {
  const StartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(),
            ),

            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
               infoText(),
               SizedBox(height: 10.h,),


               MyButton(
                   onTap: () {
                  navigatorKey.currentState?.pushNamed('/onboard');
                },
                size: Size(MediaQuery.sizeOf(context).width, 45.h),
                backgroundColor: Color(0xffAB10E2),
                radius: BorderRadius.circular(50),
                child: Center(
                  child: Text(Translate.translate("create_account", context),style: GoogleFonts.poppins(color: Colors.white,fontSize: 15.sp,fontWeight: FontWeight.w500),),
                ),
               ),

               SizedBox(height: 10.h,),

               MyButton(
                onTap: () {
                  navigatorKey.currentState?.pushNamed('/login');
                },
                size: Size(MediaQuery.sizeOf(context).width, 45.h),
                child: Center(
                  child: Text(Translate.translate("sign_in", context),style: GoogleFonts.poppins(color: Colors.black,fontSize: 15.sp,fontWeight: FontWeight.w500),),
                ),
               ),

                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  Widget infoText(){
    return Builder(
      builder: (context) {
        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(children: [
            TextSpan(text: Translate.translate("terms_intro", context),style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.w300,fontSize: 10.sp)),
            TextSpan(text: Translate.translate("terms_of_service", context),style: GoogleFonts.poppins(color: Color(0xff70AEFF),fontWeight: FontWeight.w400,fontSize: 10.sp,decoration: TextDecoration.underline)),
            TextSpan(text: Translate.translate("terms_middle", context),style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.w300,fontSize: 10.sp)),
            TextSpan(text: Translate.translate("privacy_policy", context),style: GoogleFonts.poppins(color: Color(0xff70AEFF),fontWeight: FontWeight.w400,fontSize: 10.sp,decoration: TextDecoration.underline)),
            TextSpan(text: Translate.translate("and", context),style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.w300,fontSize: 10.sp,)),
            TextSpan(text: Translate.translate("cookies_policy", context),style: GoogleFonts.poppins(color: Color(0xff70AEFF),fontWeight: FontWeight.w400,fontSize: 10.sp,decoration: TextDecoration.underline)),
          ]));
      }
    );
  }



// Widget button(){}




}