import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:shimmer/shimmer.dart';

class EditAgentView extends ConsumerStatefulWidget {
  const EditAgentView({super.key});

  @override
  ConsumerState<EditAgentView> createState() => _EditAgentViewState();
}

class _EditAgentViewState extends ConsumerState<EditAgentView> {
  late TextEditingController nameController;
  late TextEditingController characterController;
  late TextEditingController ageController;
  late List<String> selectedInterests;
  late String selectedGender;

  @override
  void initState() {
    super.initState();
    AgentModel? agent = ref.read(AllControllers.agentsProfileViewController).agent;
    
    nameController = TextEditingController(text: agent?.name ?? '');
    characterController = TextEditingController(text: agent?.character ?? '');
    ageController = TextEditingController(text: agent?.age.toString() ?? '');
    selectedInterests = agent != null ? List<String>.from(jsonDecode(agent.interests)) : [];
    selectedGender = agent?.gender ?? 'male';
  }

  @override
  void dispose() {
    nameController.dispose();
    characterController.dispose();
    ageController.dispose();
    super.dispose();
  }

  final List<String> availableInterests = [
    'Music', 'Sports', 'Movies', 'Books', 'Travel', 
    'Gaming', 'Cooking', 'Art', 'Technology', 'Fitness'
  ];

  @override
  Widget build(BuildContext context) {
    AgentModel? agent = ref.watch(AllControllers.agentsProfileViewController).agent;
    bool isLoading = ref.watch(AllControllers.agentsProfileViewController).loadingScreen;
    final userId = ref.read(AllControllers.userController)?.id?.toString();
    
    // Kontrol: Kullanıcının kendi karakteri mi?
    final bool isOwnAgent = agent != null && 
                           agent.system == 0 && 
                           agent.creatorId == userId;

    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => navigatorKey.currentState?.pop(),
          icon: Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: Text(
          Translate.translate(TranslateKeys.editFriend, context),
          style: GoogleFonts.quicksand(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: CachedNetworkImage(
                      width: 200.w,
                      height: 250.h,
                      fit: BoxFit.cover,
                      imageUrl: agent?.photoURL ?? '',
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 200.w,
                          height: 250.h,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 200.w,
                        height: 250.h,
                        color: Colors.grey[300],
                        child: Icon(Icons.person, size: 60),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30.h),

                // Name Field
                Text(
                  'Name',
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                MyTextField(
                  controller: nameController,
                  hintText: 'Enter name',
                  obscure: false,
                ),
                SizedBox(height: 20.h),

                // Character/Personality Field
                Text(
                  'Personal Traits',
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                MyTextField(
                  controller: characterController,
                  hintText: 'Describe personality traits',
                  obscure: false,
                  maxLines: 4,
                ),
                SizedBox(height: 20.h),

                // Age Field
                Text(
                  'Age',
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                MyTextField(
                  controller: ageController,
                  hintText: 'Enter age',
                  obscure: false,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20.h),

                // Gender Selection
                Text(
                  'Gender',
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedGender = 'male';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: selectedGender == 'male' 
                                ? MyColors.purple 
                                : Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Text(
                              'Male',
                              style: GoogleFonts.quicksand(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedGender = 'female';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: selectedGender == 'female' 
                                ? MyColors.purple 
                                : Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Text(
                              'Female',
                              style: GoogleFonts.quicksand(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Interests Selection
                Text(
                  'Interests',
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                ChipsChoice.multiple(
                  value: selectedInterests,
                  onChanged: (val) {
                    setState(() {
                      selectedInterests = val;
                    });
                  },
                  choiceItems: availableInterests
                      .map((interest) => C2Choice(value: interest, label: interest))
                      .toList(),
                  choiceStyle: C2ChipStyle.filled(
                    foregroundStyle: GoogleFonts.quicksand(color: Colors.black),
                    color: const Color.fromARGB(255, 238, 238, 238),
                    foregroundColor: Colors.transparent,
                    selectedStyle: C2ChipStyle.filled(
                      foregroundStyle: GoogleFonts.quicksand(
                        color: MyColors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                      foregroundColor: Colors.transparent,
                      color: MyColors.pink,
                      borderWidth: 2,
                      borderStyle: BorderStyle.solid,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  wrapped: true,
                ),
                SizedBox(height: 30.h),

                // Save Button
                GestureDetector(
                  onTap: () async {
                    if (nameController.text.isEmpty || 
                        characterController.text.isEmpty || 
                        ageController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(Translate.translate('please_fill_all_fields', context)),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await ref.read(AllControllers.agentsProfileViewController.notifier).saveEditedAgent(
                      name: nameController.text,
                      character: characterController.text,
                      age: int.tryParse(ageController.text) ?? 18,
                      gender: selectedGender,
                      interests: selectedInterests,
                    );
                  },
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: MyColors.purple,
                      borderRadius: BorderRadius.circular(50.r),
                    ),
                    child: Center(
                      child: Text(
                        isOwnAgent 
                          ? Translate.translate(TranslateKeys.save, context)
                          : Translate.translate(TranslateKeys.createFriend, context),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),

          // Loading Overlay
          if (isLoading)
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 32.w,
                      height: 32.h,
                      child: CircularProgressIndicator.adaptive(
                        backgroundColor: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

