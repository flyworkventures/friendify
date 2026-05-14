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
    final agents = ref.watch(AllControllers.agentsViewController).agents;
    if (agents == null || agents.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 197.h,
      child: ListView(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        children: agents.map((e) => agentWidget(e, appPrv)).toList(),
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
        height: 197.h,
        width: 143.w,
        margin: EdgeInsets.only(right: 10).r,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20).r,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20).r,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: agent.photoURL,
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer(
                  gradient: LinearGradient(colors: [Colors.white, Colors.grey]),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18.r),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 13,
                      ).r,
                      width: double.infinity,
                      height: 69.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18.r),
                        ),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${agent.name}, ${agent.age}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    agent.getJobByLang(
                                          app.currentLang?.languageCode ??
                                              "en",
                                        ) ??
                                        Translate.translate(
                                          "home_job_fallback",
                                          context,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.quicksand(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: SvgPicture.asset(
                                    "assets/icons/messages-2.svg",
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.contain,
                                  ),
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
      ),
    );
  }
}
