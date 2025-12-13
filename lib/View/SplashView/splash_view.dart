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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/logo.png",fit: BoxFit.cover,width: 100.w,),
                SizedBox(height: 10.h,),
                Text("Friendify",style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w600,fontSize: 36.sp),)
              ],
            ),
          ),
        ],
      ),
    );
  }
}