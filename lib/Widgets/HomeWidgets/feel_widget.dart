import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Controllers/ViewControllers/homeview_controller.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:google_fonts/google_fonts.dart';

class FeelWidget extends ConsumerWidget {
  const FeelWidget({super.key});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final home = ref.watch(AllControllers.homeViewController);
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        children: home.moods.map((e)=>tile(e, home.selectedMood, ref)).toList(),
      ),
    );
  }

Widget tile(Mood mood, String selectedMood, WidgetRef ref){
  bool isSelected = selectedMood == mood.code;
  return Expanded(
    child: GestureDetector(
      onTap: () {
        ref.read(AllControllers.homeViewController.notifier).selectMood(mood.code);
      },
      child: Container(
        height: 40.h,
        margin: EdgeInsets.only(right:mood.code != "bold" ?  10 : 0).r,
         
        decoration: BoxDecoration(
          
          color: isSelected ? Color(0xffDC7AFF).withValues(alpha: 0.2) :  Colors.white.withValues(alpha: 0.2),
          border: Border.all(color: isSelected ? Color(0xffD55EFF) : Colors.white.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(30).r
        ),
        child: Center(child: Text(mood.title,style: GoogleFonts.quicksand(color: Colors.white.withValues(alpha: 0.7),fontWeight: FontWeight.w700,fontSize: 14.sp),)),
      ),
    ),
  );
}

}