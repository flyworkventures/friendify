import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => SplashViewState();
}

class SplashViewState extends ConsumerState<SplashView> {

  @override
  void initState() {
    ref.read(AllControllers.splashViewController.notifier).init();
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Stack(
        children: [
           Image.asset("assets/onboarding.png",fit: BoxFit.cover,width: double.infinity,height: double.infinity,),
           Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset("assets/sarikadin.png",fit: BoxFit.cover,width: double.infinity,),
           ),

              Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(child: 
            Column(
              children: [
                Text("Friendify",style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 40.sp),),
                 Text("Always by your side.",style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w400,fontSize: 20.sp),),
              ],
            ),
            ),
           ),
        ],
      ),
    );
  }
}