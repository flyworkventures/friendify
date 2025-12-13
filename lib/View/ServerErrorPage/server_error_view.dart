import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:google_fonts/google_fonts.dart';

class ServerErrorView extends StatelessWidget {
  const ServerErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
           Image.asset("assets/ops.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover),
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
                      Text(Translate.translate("oops_sorry", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold),),
                     Text(Translate.translate("experiencing_issue", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 20.sp,fontWeight: FontWeight.w500),),
                     SizedBox(height: 40.h,),
                     MyButton(
                      onTap: () {
                        exit(0);
                      },
                      size: Size(MediaQuery.sizeOf(context).width, 50.h),
                      backgroundColor: MyColors.purple,
                      radius: BorderRadius.circular(40).r,
                      child: Center(
                        child: Text(Translate.translate("back", context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600),),
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