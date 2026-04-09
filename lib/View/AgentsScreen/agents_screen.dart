import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:friendfy/utils/hero_icon_converter.dart';

class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  // Filter state
  String? selectedGender; // null = Tümü, "Kadın", "Erkek"
  Set<String> selectedInterests = {};

  @override
  void initState() {
    // Edit mode'u false yap (normal kullanım için)
    ref.read(AllControllers.agentsViewController.notifier).setEditMode(false);
    getAgents();
    super.initState();
  }

  Future<void> getAgents() async{
    List<AgentModel> agents = ref.read(AllControllers.agentsViewController).agents ?? [];
    if (agents.isEmpty) {
      await ref.read(AllControllers.agentsViewController.notifier).getAgents();
    }
    // Get user's custom agents
    await ref.read(AllControllers.agentsViewController.notifier).getUserAgents();
  }

  List<AgentModel> applyFilters(List<AgentModel> agents) {
    if (selectedGender == null && selectedInterests.isEmpty) {
      return agents;
    }

    return agents.where((agent) {
      // Gender filter
      if (selectedGender != null && agent.gender != selectedGender) {
        return false;
      }

      // Interests filter
      if (selectedInterests.isNotEmpty) {
        try {
          List<String> agentInterests = List.from(jsonDecode(agent.interestsType));
          bool hasMatchingInterest = agentInterests.any((interest) => selectedInterests.contains(interest));
          if (!hasMatchingInterest) {
            return false;
          }
        } catch (e) {
          return false;
        }
      }

      return true;
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    List<AgentModel> allAgents = ref.watch(AllControllers.agentsViewController).agents ?? [];
    List<AgentModel> allUserAgents = ref.watch(AllControllers.agentsViewController).userAgents ?? [];
    bool loading = ref.watch(AllControllers.agentsViewController.notifier).loading;

    // Apply filters
    List<AgentModel> agents = applyFilters(allAgents);
    List<AgentModel> userAgents = applyFilters(allUserAgents);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        
        title: Text(Translate.translate("select_character", context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w700,fontSize: 17.sp),),
   /*     actions: [
          IconButton(
            onPressed: () => _showFilterBottomSheet(context), 
            icon: HeroIcon(HeroIcons.adjustmentsHorizontal)
          )
        ],  */
      ),
    
      body: loading 
      ? Center(
        child:  SizedBox(width: 35,height: 35,child: CircularProgressIndicator(color: Colors.black,),),
      )
      : SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 90.h),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
       
                // User's Personal Friends Section
                if(userAgents.isNotEmpty)...[
                  Padding(
                    padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 15.h, bottom: 10.h),
                    child: Text(
                      Translate.translate("your_personal_friends", context),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18.sp
                      ),
                    ),
                  ),
                  GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(left: 20.w, right: 20.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      mainAxisExtent: 297.h,
                      mainAxisSpacing: 10.w,
                      crossAxisSpacing: 5.h,
                      crossAxisCount: 2
                    ),
                    itemCount: userAgents.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      AgentModel item = userAgents[index];
                      return agentWidget(item);
                    }
                  ),
                  SizedBox(height: 20.h),
                ],

                // Others (System Agents) Section
                if(agents.isNotEmpty)...[
 
                  GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      mainAxisExtent: 262.h,
                      mainAxisSpacing: 10.w,
                      crossAxisSpacing: 5.h,
                      crossAxisCount: 2
                    ),
                    itemCount: agents.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      AgentModel item = agents[index];
                      return agentWidget(item);
                    }
                  )
                ]
            ],
          ),
        ),
      ),
    );
  }

Future createChat(AgentModel agent) async{


   String? token = ref.read(AllControllers.userController)?.token;

 var res = await http.post(Uri.parse("${AppConstants.baseURL}${AppConstants.createChat}",),

  headers: {"x-auth-token": token!,'Content-Type': 'application/json'},
  body: jsonEncode(
    {
   "userId": 1 ,
   "botId": 1
}
  )
  );
debugPrint(res.body);
  if (res.statusCode == 200) {
    var json = jsonDecode(res.body);
    if (json["msg"] == "Created") {
      debugPrint(json["conversationId"]);
    
      
    }
  }

}



Widget agentWidget(AgentModel agent){
  List<Widget> icons = [];
  List<String> interest = List.from(jsonDecode(agent.interestsType));
  for (var element in interest) {
    icons.add(HeroIcon(interestToIcon[element]!,color: Colors.white,size: 18,style: HeroIconStyle.solid,));
  }
  
  return GestureDetector(
    onTap: (){
      // Edit mode kontrolü: Eğer anasayfadaki "Karakter Düzenle" butonundan gelindiyse direkt edit, değilse profil ekranı
      final controller = ref.read(AllControllers.agentsViewController.notifier);
      final editMode = controller.getEditMode();
      
      ref.read(AllControllers.agentsProfileViewController.notifier).changeAgentModel(agent);
      
      if (editMode) {
        // Anasayfadaki "Karakter Düzenle" butonundan gelindi - direkt edit ekranına git
        navigatorKey.currentState?.pushNamed('/editAgentView');
      } else {
        // Normal kullanım - karakter profil ekranına git
        navigatorKey.currentState?.pushNamed('/agentDetails');
      }
    },
    
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3)
        )
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadiusGeometry.circular(16),
              child: CachedNetworkImage(
                imageUrl: agent.photoURL,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 186.h,
                
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.person, size: 50),
                ),
              ),
            ),
          ),
          Align(
      alignment: Alignment.bottomLeft,
      child: Container(
             padding: EdgeInsets.only(right: 10.w,left: 10.w,bottom: 10.h),
         decoration: BoxDecoration(
      
        ),
             
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İsim
            Text(
              agent.name,
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  )
                ]
              ),
            ),

            // Karakter (speakingStyle)
            if (agent.speakingStyle != null && agent.speakingStyle!.isNotEmpty)
              Text(
                agent.speakingStyle ?? "",
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 10.sp,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    )
                  ]
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
       
   
          ],
        ),
      
        ),
      ),
            
        ]  
        )));
  
}

  void _showFilterBottomSheet(BuildContext context) {
    // Temporary state for bottom sheet
    String? tempSelectedGender = selectedGender;
    Set<String> tempSelectedInterests = Set.from(selectedInterests);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Container(
              padding: EdgeInsets.all(20.w),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Translate.translate("filter", context),
                          style: GoogleFonts.quicksand(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // Gender Filter
                    Text(
                      Translate.translate("gender", context),
                      style: GoogleFonts.quicksand(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 10.w,
                      children: [
                        _filterChip(
                          label: Translate.translate("all", context),
                          selected: tempSelectedGender == null,
                          onTap: () {
                            setBottomSheetState(() {
                              tempSelectedGender = null;
                            });
                          },
                        ),
                        _filterChip(
                          label: Translate.translate("female", context),
                          selected: tempSelectedGender == "Kadın",
                          onTap: () {
                            setBottomSheetState(() {
                              tempSelectedGender = "Kadın";
                            });
                          },
                        ),
                        _filterChip(
                          label: Translate.translate("male", context),
                          selected: tempSelectedGender == "Erkek",
                          onTap: () {
                            setBottomSheetState(() {
                              tempSelectedGender = "Erkek";
                            });
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 25.h),

                    // Interests Filter
                    Text(
                      Translate.translate("interests", context),
                      style: GoogleFonts.quicksand(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: interestToIcon.keys.map((interest) {
                        return _filterChip(
                          label: Translate.translate(interest, context),
                          selected: tempSelectedInterests.contains(interest),
                          icon: HeroIcon(
                            interestToIcon[interest]!,
                            size: 16,
                            color: tempSelectedInterests.contains(interest)
                                ? Colors.white
                                : Colors.black,
                          ),
                          onTap: () {
                            setBottomSheetState(() {
                              if (tempSelectedInterests.contains(interest)) {
                                tempSelectedInterests.remove(interest);
                              } else {
                                tempSelectedInterests.add(interest);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 30.h),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setBottomSheetState(() {
                                tempSelectedGender = null;
                                tempSelectedInterests.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 15.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              side: BorderSide(color: Colors.grey),
                            ),
                            child: Text(
                              Translate.translate("clear_filters", context),
                              style: GoogleFonts.quicksand(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedGender = tempSelectedGender;
                                selectedInterests = tempSelectedInterests;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xffAB10E2),
                              padding: EdgeInsets.symmetric(vertical: 15.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              Translate.translate("apply_filters", context),
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    Widget? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? Color(0xffAB10E2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon,
              SizedBox(width: 5.w),
            ],
            Text(
              label,
              style: GoogleFonts.quicksand(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

}