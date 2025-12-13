
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:google_fonts/google_fonts.dart';


class FaqView extends StatefulWidget {
  const FaqView({super.key});

  @override
  State<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends State<FaqView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              CupertinoIcons.back,
              color: Colors.black,
            )),
        backgroundColor: Colors.transparent,
        title: Text(
       Translate.translate("faqs", context),
          style: GoogleFonts.quicksand(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 22.sp),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              tile(
                title:Translate.translate("faq_1_question", context),
                subtitle: Translate.translate("faq_1_answer", context),
              ),
              tile(
                title: Translate.translate("faq_2_question", context),
                subtitle: Translate.translate("faq_2_answer", context),
              ),
              tile(
                title: Translate.translate("faq_3_question", context),
                subtitle: Translate.translate("faq_3_answer", context),
              ),
              tile(
                title: Translate.translate("faq_4_question", context),
                subtitle: Translate.translate("faq_4_answer", context),
              ),
              tile(
                title: Translate.translate("faq_5_question", context),
                subtitle: Translate.translate("faq_5_answer", context),
              ),
              tile(
                title: Translate.translate("faq_6_question", context),
                subtitle: Translate.translate("faq_6_answer", context),
              ),
              tile(
                title: Translate.translate("faq_7_question", context),
                subtitle: Translate.translate("faq_7_answer", context),
              ),
              tile(
                title: Translate.translate("faq_8_question", context),
                subtitle: Translate.translate("faq_8_answer", context)
              ),
              tile(
                title: Translate.translate("faq_9_question", context),
                subtitle: Translate.translate("faq_9_answer", context),
              ),
              tile(
                title: Translate.translate("faq_10_question", context),
                subtitle: Translate.translate("faq_10_answer", context),
              ),
        tile(
                title: Translate.translate("faq_11_question", context),
                subtitle: Translate.translate("faq_11_answer", context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget tile({required String title, required String subtitle}) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory, // Tıklama efektini kaldır
      ),
      child: Container(
    
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(width: 1,color: Colors.grey)),

       
        ),
        child: ExpansionTile(
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            enableFeedback: false,
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            childrenPadding: const EdgeInsets.only(left: 20),
            title: Text(
              title,
              style: GoogleFonts.quicksand(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp),
            ),
            children: [
              Text(
                subtitle,
                style: GoogleFonts.quicksand(
                    color: Colors.black.withOpacity(0.35),
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp),
              )
            ],
          ),
      ),
    );
  }
}