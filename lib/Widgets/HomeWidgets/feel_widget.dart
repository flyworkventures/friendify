import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/ViewControllers/homeview_controller.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:google_fonts/google_fonts.dart';

class FeelWidget extends ConsumerWidget {
  const FeelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(AllControllers.homeViewController);
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        children: home.moods
            .map((e) => tile(e, home.selectedMood, ref, context))
            .toList(),
      ),
    );
  }

  Widget tile(
    Mood mood,
    String selectedMood,
    WidgetRef ref,
    BuildContext context,
  ) {
    bool isSelected = selectedMood == mood.code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref
              .read(AllControllers.homeViewController.notifier)
              .selectMood(mood.code);
        },
        child: Container(
          height: 40.h,
          margin: EdgeInsets.only(right: mood.code != "bold" ? 10 : 0).r,

          decoration: BoxDecoration(
            color: isSelected
                ? Color(0xffDC7AFF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: isSelected
                  ? Color(0xffD55EFF)
                  : Colors.white.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(30).r,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6).r,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _localizedMoodTitle(mood, context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedMoodTitle(Mood mood, BuildContext context) {
    switch (mood.code) {
      case "relaxed":
        return "😌 ${Translate.translate("mood_relaxed", context)}";
      case "fun":
        return "😂 ${Translate.translate("mood_fun", context)}";
      case "deep":
        return "💭 ${Translate.translate("mood_deep", context)}";
      case "bold":
        return "💪 ${Translate.translate("mood_bold", context)}";
      default:
        return mood.title;
    }
  }
}
