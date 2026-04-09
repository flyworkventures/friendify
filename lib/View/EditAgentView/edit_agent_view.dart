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
  late TextEditingController newInterestController;
  late List<String> selectedInterests;
  late List<String> availableInterests; // Dinamik liste
  late String selectedGender;

  @override
  void initState() {
    super.initState();
    AgentModel? agent = ref.read(AllControllers.agentsProfileViewController).agent;
    
    nameController = TextEditingController(text: agent?.name ?? '');
    characterController = TextEditingController(text: agent?.character ?? '');
    ageController = TextEditingController(text: agent?.age.toString() ?? '');
    newInterestController = TextEditingController();
    
    // Başlangıç ilgi alanları listesi (localization key'leri)
    final defaultInterests = [
      'music', 'sports', 'movies', 'books', 'travel', 
      'gaming', 'cooking', 'art', 'technology', 'fitness'
    ];
    
    // Agent'tan gelen ilgi alanları
    final agentInterests = agent != null ? List<String>.from(jsonDecode(agent.interests)) : [];
    selectedInterests = List.from(agentInterests);
    
    // Mevcut ilgi alanları listesini oluştur: default + agent'tan gelen özel ilgi alanları
    availableInterests = List.from(defaultInterests);
    for (var interest in agentInterests) {
      if (!availableInterests.contains(interest)) {
        availableInterests.add(interest); // Özel ilgi alanlarını ekle
      }
    }
    
    selectedGender = agent?.gender ?? 'male';
  }

  @override
  void dispose() {
    nameController.dispose();
    characterController.dispose();
    ageController.dispose();
    newInterestController.dispose();
    super.dispose();
  }

  void _addCustomInterest() {
    final newInterest = newInterestController.text.trim();
    if (newInterest.isNotEmpty && !availableInterests.contains(newInterest)) {
      setState(() {
        availableInterests.add(newInterest);
        selectedInterests.add(newInterest);
        newInterestController.clear();
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      selectedInterests.remove(interest);
      // Eğer özel bir ilgi alanıysa (default listede yoksa), listeden de kaldır
      final defaultInterests = [
        'music', 'sports', 'movies', 'books', 'travel', 
        'gaming', 'cooking', 'art', 'technology', 'fitness'
      ];
      if (!defaultInterests.contains(interest)) {
        availableInterests.remove(interest);
      }
    });
  }

  /// İlgi alanını localize eder (default listede varsa translate eder, yoksa olduğu gibi döner)
  String _getLocalizedInterest(String interest) {
    final defaultInterests = [
      'music', 'sports', 'movies', 'books', 'travel', 
      'gaming', 'cooking', 'art', 'technology', 'fitness'
    ];
    
    // Eğer default listede varsa, localization key olarak kullan
    if (defaultInterests.contains(interest.toLowerCase())) {
      return Translate.translate(interest.toLowerCase(), context);
    }
    
    // Özel ilgi alanı ise olduğu gibi döndür
    return interest;
  }

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
                  Translate.translate("name", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                MyTextField(
                  controller: nameController,
                  hintText: Translate.translate("enter_name", context),
                  obscure: false,
                ),
                SizedBox(height: 20.h),

                // Character/Personality Field
                Text(
                  Translate.translate("personal_traits", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                MyTextField(
                  controller: characterController,
                  hintText: Translate.translate("describe_personality_traits", context),
                  obscure: false,
                  maxLines: 4,
                ),
                SizedBox(height: 20.h),

                // Age Field
                Text(
                  Translate.translate("age", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                MyTextField(
                  controller: ageController,
                  hintText: Translate.translate("enter_age", context),
                  obscure: false,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20.h),

                // Gender Selection
                Text(
                  Translate.translate("gender", context),
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
                              Translate.translate("male", context),
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
                              Translate.translate("female", context),
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
                  Translate.translate("interests", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                
                // Seçili ilgi alanları (silinebilir chip'ler - hafif silik, sadece seçili olanlar)
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: selectedInterests.map((interest) {
                    return Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 60.w, // Ekran genişliğinden padding çıkar
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              // İlgi alanını localize et (eğer default listede varsa)
                              _getLocalizedInterest(interest),
                              style: GoogleFonts.quicksand(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 13.sp,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: () => _removeInterest(interest),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16.h),
                
                // Mevcut ilgi alanlarından seçim (sadece seçili olmayanlar gösterilecek)
                ChipsChoice.multiple(
                  value: selectedInterests,
                  onChanged: (val) {
                    setState(() {
                      selectedInterests = val;
                    });
                  },
                  choiceItems: availableInterests
                      .where((interest) => !selectedInterests.contains(interest)) // Sadece seçili olmayanları göster
                      .map((interest) => C2Choice(
                        value: interest, 
                        label: _getLocalizedInterest(interest)
                      ))
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
                SizedBox(height: 16.h),
                
                // Yeni ilgi alanı ekleme
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newInterestController,
                        decoration: InputDecoration(
                          hintText: Translate.translate("add_custom_interest", context),
                          hintStyle: GoogleFonts.quicksand(
                            color: Colors.grey.shade400,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: MyColors.purple, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
                        ),
                        style: GoogleFonts.quicksand(),
                        onSubmitted: (_) => _addCustomInterest(),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    GestureDetector(
                      onTap: _addCustomInterest,
                      child: Container(
                        width: 50.w,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: MyColors.purple,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
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

