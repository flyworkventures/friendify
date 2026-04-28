import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class QuickMessage extends ConsumerStatefulWidget {
  const QuickMessage({super.key});

  @override
  ConsumerState<QuickMessage> createState() => _QuickMessageState();
}

class _QuickMessageState extends ConsumerState<QuickMessage> {
  @override
  Widget build(BuildContext context) {
    List<AgentModel>? agents = ref
        .read(AllControllers.agentsViewController)
        .agents;
    return SizedBox(
      height: 240.h,
      child: ListView(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        children: agents!.map((e) => agentWidget(e)).toList(),
      ),
    );
  }

  Widget agentWidget(AgentModel agent) {
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
                    height: 197.h,
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
                      vertical: 18,
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          agent.name,
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                          ),
                        ),

                        Container(
                          width: 24.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40).r,
                            gradient: LinearGradient(
                              colors: [Color(0xffAB10E2), Color(0xff2D30FF)],
                            ),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              "assets/icons/send-magic.svg",
                              width: 13.w,
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
