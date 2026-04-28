import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/locale_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class YourMatches extends ConsumerStatefulWidget {
  const YourMatches({super.key});

  @override
  ConsumerState<YourMatches> createState() => _YourMatchesState();
}

class _YourMatchesState extends ConsumerState<YourMatches> {
  @override
  Widget build(BuildContext context) {
    final appPrv = ref.watch(appProvider);
    List<AgentModel>? agents = ref
        .read(AllControllers.agentsViewController)
        .agents;
    return SizedBox(
      height: 240.h,
      child: ListView(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        children: agents!.map((e) => agentWidget(e, appPrv)).toList(),
      ),
    );
  }

  Widget agentWidget(AgentModel agent, AppProvider app) {
    return GestureDetector(
      onTap: () {
        ref
            .read(AllControllers.agentsProfileViewController.notifier)
            .startChat(agent);
      },
      child: Container(
        height: 240.h,
        width: 152.w,
        margin: EdgeInsets.only(right: 10).r,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20).r),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20).r,
              child: CachedNetworkImage(
                imageUrl: agent.photoURL,
                height: 240.h,
                width: 152.w,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer(
                  gradient: LinearGradient(colors: [Colors.white, Colors.grey]),
                  child: Container(
                    height: 240.h,
                    width: 152.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20).r,
                    ),
                  ),
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20).r,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 13,
                    ).r,
                    width: MediaQuery.sizeOf(context).width,
                    height: 69.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        end: Alignment.topCenter,
                        begin: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${agent.name}, ${agent.age}",
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                agent.getJobByLang(
                                      app.currentLang?.countryCode ?? "en",
                                    ) ??
                                    Translate.translate(
                                      "home_job_fallback",
                                      context,
                                    ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: Container(
                            width: 24.w,
                            height: 24.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40).r,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                "assets/icons/messages-2.svg",
                                width: 13.w,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
