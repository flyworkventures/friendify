import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:purchases_flutter/object_wrappers.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    return  PaywallView(displayCloseButton: true,);
    
     /*Scaffold(
      
     appBar: AppBar(
        centerTitle: false,
      //  title: Text("Premium",style: GoogleFonts.quicksand(color: Colors.black,fontSize: 17.sp,fontWeight: FontWeight.w600),),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20,vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                   Text(
            Translate.translate('try_premium_free', context),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 24.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20.h),
          Text(Translate.translate('get_unlimited_access', context),
          textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w500)),

             SizedBox(height: 30.h),
             feature(Translate.translate('skip_ads', context)),
             feature(Translate.translate('unlimited_character_selection', context)),
             feature(Translate.translate('character_edit', context)),
             feature(Translate.translate('expanded_memory', context)),
              SizedBox(height: 30.h),
              button(),
              SizedBox(height: 10.h),
                        Text(Translate.translate('trial_charge_info', context),
          textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w500)),
          ],
        ),
      )), 
    );*/
  }

Widget button(){
  return Container(
    width: MediaQuery.sizeOf(context).width,
    height: 50.h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(49.r),
      gradient: LinearGradient(colors: [MyColors.blue,MyColors.purple],begin: Alignment.centerLeft,end: Alignment.centerRight)
    ),
    child: Center(
      child: Text(Translate.translate('start_free_trial', context),style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 18.sp),),
    ),
  );
}

  Widget feature(String feature){
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      child: Row(
      
        children: [
          HeroIcon(HeroIcons.checkCircle,color: Colors.greenAccent,style: HeroIconStyle.solid,),
          SizedBox(width: 10.w,),
          Text(feature,style: GoogleFonts.poppins(color: Colors.black,fontSize: 14.sp,fontWeight: FontWeight.w400),)
        ],
      ),
    );
  }
}