import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/ViewControllers/agent_profile_view_controller.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/hero_icon_converter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:shimmer/shimmer.dart';

import '../../AppLocalizations/translate_keys.dart';

class AgentProfileView extends ConsumerStatefulWidget {
  const AgentProfileView({super.key});

  @override
  ConsumerState<AgentProfileView> createState() => _AgentProfileViewState();
}

class _AgentProfileViewState extends ConsumerState<AgentProfileView> {
    List<Widget> icons = [];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();

  }

  init(){
        
          AgentModel? agent = ref.read(AllControllers.agentsProfileViewController).agent;
  List<String> interest = List.from(jsonDecode(agent?.interestsType));
  for (var element in interest) {
    icons.add(HeroIcon(interestToIcon[element]!,color: MyColors.purple,size: 18,style: HeroIconStyle.outline,));
    setState(() {
      
    });
  }
  }
  @override
  Widget build(BuildContext context) {
    AgentModel? agent = ref.watch(AllControllers.agentsProfileViewController).agent;
    final userId = ref.read(AllControllers.userController)?.id?.toString();
    
    // Kontrol: Kullanıcının kendi karakteri mi?
    final bool isOwnAgent = agent != null && 
                           agent.system == 0 && 
                           agent.creatorId == userId;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(onPressed: ()=> navigatorKey.currentState?.pop(), icon: Icon(CupertinoIcons.back,color: Colors.white,)),

      ),
      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 75.h),
            child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadiusGeometry.only(bottomLeft: Radius.circular(40.r),bottomRight: Radius.circular(40).r),
                  child: CachedNetworkImage(
                    width: MediaQuery.sizeOf(context).width,
                    height: 336.h,
                    fit: BoxFit.cover,
                    imageUrl: agent!.photoURL,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: 336.h,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: MediaQuery.sizeOf(context).width,
                      height: 336.h,
                      color: Colors.grey[300],
                      child: Icon(Icons.person, size: 80),
                    ),
                  ),
                ),
                SizedBox(height: 40.h,),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 15),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       children: [
                         Text(agent.name,style: GoogleFonts.quicksand(fontWeight: FontWeight.w700,fontSize: 24.sp),),
                         SizedBox(width: 10.w,),
                         Row(
                          children: icons,
                         )
                       ],
                     ),
                     SizedBox(height: 10.h,),
                      Text(Translate.translate("personal_traits", context),style: GoogleFonts.quicksand(fontWeight: FontWeight.w700,fontSize: 14.sp),),
                      Text(agent.character,style: GoogleFonts.quicksand(fontWeight: FontWeight.w400,fontSize: 15.sp),),
           SizedBox(height: 20.h,),
                      Text(Translate.translate("interests", context),style: GoogleFonts.quicksand(fontWeight: FontWeight.w700,fontSize: 14.sp),),
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width,
           
                        child: ChipsChoice.single(
             
                 
                          
                          choiceItems: (List.from(jsonDecode(agent.interests))).map((a)=> C2Choice(label: a,value: a)).toList(),
                            placeholderStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.bold),
                            choiceStyle: C2ChipStyle(
                              margin: EdgeInsets.zero,
                              foregroundStyle:  GoogleFonts.quicksand(color: Colors.black),
                              backgroundColor: Colors.grey,
                              backgroundOpacity: 0.1,
                              
                              borderRadius: BorderRadius.circular(30),
                              avatarBackgroundColor: Colors.red
                              
                            ),
                         
                            direction: Axis.horizontal,
                            wrapped: true,
                            
                              value: agent.interests,
                             onChanged: (value) {
                               
                             },
                        
                            ),
                      ),





          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15).copyWith(top:40.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: (){
                    navigatorKey.currentState?.pushNamed("/editAgentView");
                  },
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15), 
                      borderRadius: BorderRadius.circular(50.r),
                      border: Border.all(color: MyColors.purple, width: 2)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HeroIcon(HeroIcons.pencilSquare,color: MyColors.purple,style: HeroIconStyle.solid,),
                        SizedBox(width: 10.w,),
                        Text(Translate.translate("edit", context),style: GoogleFonts.quicksand(color:  MyColors.purple,fontWeight: FontWeight.w700,fontSize: 16.sp),)
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10.h,),
                GestureDetector(
                  onTap: (){
                    ref.read(AllControllers.agentsProfileViewController.notifier).startChat(agent);
                  },
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: MyColors.purple, borderRadius: BorderRadius.circular(50.r)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HeroIcon(HeroIcons.sparkles,color: Colors.white,style: HeroIconStyle.solid,),
                        SizedBox(width: 10.w,),
                        Text(Translate.translate("chat_with", context).replaceAll("%%name%%", agent.name),style: GoogleFonts.quicksand(color:  Colors.white,fontWeight: FontWeight.w700,fontSize: 16.sp),)
                      ],
                    ),
                  ),
                ),
                // Silme butonu - sadece kendi karakteri için
                if (isOwnAgent) ...[
                  SizedBox(height: 10.h,),
                  GestureDetector(
                    onTap: () async {
                      // Silme onayı
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(Translate.translate(TranslateKeys.delete, context)),
                          content: Text('Are you sure you want to delete this character?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(Translate.translate(TranslateKeys.cancel, context)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(
                                Translate.translate(TranslateKeys.delete, context),
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true) {
                        await ref.read(AllControllers.agentsProfileViewController.notifier).deleteAgent();
                      }
                    },
                    child: Container(
                      width: MediaQuery.sizeOf(context).width,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: Colors.red, 
                        borderRadius: BorderRadius.circular(50.r)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeroIcon(HeroIcons.trash,color: Colors.white,style: HeroIconStyle.solid,),
                          SizedBox(width: 10.w,),
                          Text(
                            Translate.translate(TranslateKeys.delete, context),
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16.sp
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),


                  ],
                 ),
               )
              ],
            ),
          ),




           if(ref.watch(AllControllers.agentsProfileViewController).loadingScreen == true)...[
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              color: Colors.black.withValues(alpha: 0.2),
              child: Center(
                child: Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7),borderRadius: BorderRadius.circular(10.r)),
                  child: Center(
                    child: SizedBox(width: 32.w,height: 32.h,child: CircularProgressIndicator.adaptive(backgroundColor: Colors.white,)),
                  ),
                ),
              ),
            )
           ]


        ],
      ),
    );
  }
}