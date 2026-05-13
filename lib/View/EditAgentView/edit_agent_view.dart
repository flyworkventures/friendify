import 'dart:convert';
import 'dart:developer';
import 'dart:math' show Random;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

class EditAgentView extends ConsumerStatefulWidget {
  const EditAgentView({super.key, this.createFlow = false});

  final bool createFlow;

  @override
  ConsumerState<EditAgentView> createState() => _EditAgentViewState();
}

class _VoiceOption {
  const _VoiceOption({
    required this.id,
    required this.name,
    required this.elevenlabsId,
    required this.mp3Url,
    required this.gender,
  });

  final int id;
  final String name;
  final String elevenlabsId;
  final String mp3Url;
  final String gender;

  factory _VoiceOption.fromJson(Map<String, dynamic> json) {
    return _VoiceOption(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '').toString(),
      elevenlabsId: (json['elevenlabsId'] ?? '').toString(),
      mp3Url: (json['mp3Url'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString().toLowerCase(),
    );
  }
}

class _EditAgentViewState extends ConsumerState<EditAgentView> {
  late TextEditingController nameController;
  late TextEditingController characterController;
  late TextEditingController ageController;
  late List<String> selectedInterests;
  late String selectedGender;
  bool _isVoicesLoading = true;
  String? _voiceLoadError;
  List<_VoiceOption> _allVoices = [];
  List<_VoiceOption> _filteredVoices = [];
  String? selectedVoiceId;
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _playingVoiceId;
  bool _isTemplateLoading = false;
  String? selectedPhotoUrl;

  @override
  void initState() {
    super.initState();
    AgentModel? agent = ref.read(AllControllers.agentsProfileViewController).agent;

    if (widget.createFlow) {
      nameController = TextEditingController();
      characterController = TextEditingController();
      ageController = TextEditingController(text: '18');
      selectedInterests = [];
      selectedGender = 'female';
      selectedVoiceId = null;
      _loadRandomSystemTwoAgentTemplate(genderFilter: selectedGender);
    } else {
      nameController = TextEditingController(text: agent?.name ?? '');
      characterController = TextEditingController(text: agent?.character ?? '');
      ageController = TextEditingController(text: agent?.age.toString() ?? '');
      selectedInterests = _parseInterests(agent?.interests);
      selectedGender = _normalizeGender(agent?.gender);
      selectedVoiceId = agent?.voiceId;
      selectedPhotoUrl = agent?.photoURL;
      _loadSavedSelectedPhoto(agent);
    }
    _loadVoices();
  }

  Future<void> _loadSavedSelectedPhoto(AgentModel? agent) async {
    if (agent == null) return;
    final savedPhotoUrl = await LocalService.getSelectedAgentPhoto(agent.id);
    if (!mounted) return;
    setState(() {
      selectedPhotoUrl = savedPhotoUrl ?? agent.photoURL;
    });
  }


  @override
  void dispose() {
    nameController.dispose();
    characterController.dispose();
    ageController.dispose();
    _previewPlayer.stop();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AgentModel? agent = ref.watch(AllControllers.agentsProfileViewController).agent;
    bool isLoading = ref.watch(AllControllers.agentsProfileViewController).loadingScreen;
    final topImageUrls = _resolveTopImageUrls(agent);

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: () => navigatorKey.currentState?.pop(),
            icon: Icon(CupertinoIcons.back, color: Colors.white),
          ),
          title: Text(
            Translate.translate(
              widget.createFlow
                  ? TranslateKeys.createCharacterTitle
                  : TranslateKeys.editCharacterTitle,
              context,
            ),
            style: GoogleFonts.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
            ),
          ),
          centerTitle: true,
          actions: [
            if (widget.createFlow)
              IconButton(
                onPressed: _isTemplateLoading
                    ? null
                    : () => _loadRandomSystemTwoAgentTemplate(
                        syncFormFields: false,
                        genderFilter: selectedGender,
                      ),
                icon: SvgPicture.asset(
                  "assets/icons/zar.svg",
                  width: 24.w,
                  height: 24.h,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [

            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      3,
                      (index) {
                        final imageUrl = topImageUrls[index];
                        final isSelected = selectedPhotoUrl == imageUrl;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == 2 ? 0 : 8.w),
                            child: GestureDetector(
                              onTap: imageUrl.trim().isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedPhotoUrl = imageUrl;
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.all(isSelected ? 3.r : 0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFCE64FF)
                                        : Colors.transparent,
                                    width: 2.r,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18.r),
                                  child: AspectRatio(
                                    aspectRatio: 0.9,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CachedNetworkImage(
                                          fit: BoxFit.cover,
                                          alignment: Alignment(0, -1),
                                          imageUrl: imageUrl,
                                          placeholder: (context, url) => Shimmer.fromColors(
                                            baseColor: Colors.white.withValues(alpha: 0.14),
                                            highlightColor: Colors.white.withValues(alpha: 0.24),
                                            child: Container(color: Colors.white10),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.white10,
                                            child: const Icon(Icons.person, color: Colors.white70, size: 34),
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            top: 8.r,
                                            right: 8.r,
                                            child: Container(
                                              width: 24.r,
                                              height: 24.r,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFCE64FF),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16.r,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                  _title(Translate.translate(TranslateKeys.editCharacterNameLabel, context)),
                  SizedBox(height: 8.h),
                  _darkField(
                    controller: nameController,
                    hint: Translate.translate(TranslateKeys.editCharacterNameHint, context),
                  ),
                  SizedBox(height: 16.h),
                  _title(Translate.translate(TranslateKeys.gender, context)),
                  SizedBox(height: 8.h),
                  _buildGenderSegmentedControl(context),
                  SizedBox(height: 16.h),
                  _titleWithIcon(
                    icon: "assets/icons/settings.svg",
                    title: Translate.translate(TranslateKeys.editCharacterInterestsTraitsTitle, context),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    Translate.translate(TranslateKeys.editCharacterInterestsTraitsDesc, context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  _darkFieldSecond(
                    controller: characterController,
                    hint: Translate.translate(TranslateKeys.editCharacterInterestsTraitsHint, context),
                    maxLines: 4,
                  ),
                  SizedBox(height: 20.h),
                  _titleWithIcon(
                    icon: "assets/icons/selectvoice.svg",
                    title: Translate.translate(TranslateKeys.editCharacterSelectVoice, context),
                  ),
                  SizedBox(height: 10.h),
                  if (_isVoicesLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      child: Center(
                        child: SizedBox(
                          width: 28.w,
                          height: 28.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (_voiceLoadError != null)
                    _voiceErrorWidget()
                  else if (_filteredVoices.isEmpty)
                    _emptyVoiceWidget()
                  else
                    ..._buildVoiceCards(),
                  SizedBox(height: 26.h),
                  GestureDetector(
                    onTap: () async {
                      if (_isTemplateLoading) return;
                      if (nameController.text.isEmpty || characterController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(Translate.translate('please_fill_all_fields', context)),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      final currentAgent =
                          ref.read(AllControllers.agentsProfileViewController).agent;
                      if (currentAgent == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Translate.translate(TranslateKeys.agentCreateFailed, context),
                            ),
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
                        voiceId: selectedVoiceId,
                        selectedPhotoUrl: selectedPhotoUrl,
                        isCreateFlow: widget.createFlow,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 58.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30.r),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC15BFF), Color(0xFF3F3CFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeroIcon(HeroIcons.sparkles,color: Colors.white,style: HeroIconStyle.solid,),
                          SizedBox(width: 10.w,),
                          Center(
                            child: Text(
                              Translate.translate(TranslateKeys.save, context),
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      
            if (_isTemplateLoading)
              Container(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: SizedBox(
                    width: 32.w,
                    height: 32.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      
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
      ),
    );
  }

  List<String> _resolveTopImageUrls(AgentModel? agent) {
    final urls = (agent?.photoURLs ?? [])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      final fallback = agent?.photoURL ?? '';
      return List<String>.filled(3, fallback);
    }
    if (urls.length >= 3) {
      return urls.take(3).toList();
    }
    final filled = List<String>.from(urls);
    while (filled.length < 3) {
      filled.add(urls.last);
    }
    return filled;
  }

  Widget _title(String text) {
    return Text(
      text,
      style: GoogleFonts.quicksand(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 12.sp,
      ),
    );
  }

  Widget _titleWithIcon({required String icon, required String title}) {
    return Row(
      children: [
        SvgPicture.asset(icon, width: 20.w, height: 20.h, colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),),
        SizedBox(width: 8.w),
        _title(title),
      ],
    );
  }

  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    );
  }


  BoxDecoration _sectionDecoration2() {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colors.white),
    );
  }



  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      height: 40.h,
      decoration: _sectionDecoration(),
      child: TextField(
        controller: controller,
      
        maxLines: maxLines,
        style: GoogleFonts.quicksand(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.quicksand(
            color: Colors.white.withValues(alpha: 0.48),
            fontWeight: FontWeight.w500,
            fontSize: 14.sp,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        ),
      ),
    );
  }



  Widget _darkFieldSecond({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      height: 84.h,
      decoration: _sectionDecoration2(),
      child: TextField(
        controller: controller,
      
        maxLines: maxLines,
        style: GoogleFonts.quicksand(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
        decoration: InputDecoration(
          fillColor: Colors.transparent,
          filled: false,
          hintText: hint,
          hintStyle: GoogleFonts.quicksand(
            color: Colors.white.withValues(alpha: 0.48),
            fontWeight: FontWeight.w500,
            fontSize: 14.sp,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        ),
      ),
    );
  }



  Widget _buildGenderSegmentedControl(BuildContext context) {
    const unselectedTint = Color(0xFFB8B8C0);
    final selected = selectedGender == 'private' ? null : selectedGender;

    Widget segment({
      required String label,
      required String? value,
      required bool selected,
      required Widget leading,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final previousGender = selectedGender;
              setState(() {
                selectedGender = value ?? 'private';
                _applyVoicesForGender();
              });
              if (widget.createFlow && previousGender != selectedGender) {
                _loadRandomSystemTwoAgentTemplate(
                  syncFormFields: false,
                  genderFilter: selectedGender,
                );
              }
            },
            borderRadius: BorderRadius.circular(12.r),
            splashColor: Colors.white.withValues(alpha: 0.08),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric( horizontal: 4.w),
              height: 34.h,
              decoration: BoxDecoration(
                color: selected ? MyColors.purple : Colors.transparent,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.quicksand(
                        color: selected ? Colors.white : unselectedTint,
                        fontSize: 13.sp,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          segment(
            label: Translate.translate(TranslateKeys.male, context),
            value: 'male',
            selected: selected == 'male',
            leading: SvgPicture.asset(
              'assets/male.svg',
              width: 18.w,
              height: 18.w,
              colorFilter: ColorFilter.mode(
                selected == 'male' ? Colors.white : unselectedTint,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          segment(
            label: Translate.translate(TranslateKeys.female, context),
            value: 'female',
            selected: selected == 'female',
            leading: SvgPicture.asset(
              'assets/female.svg',
              width: 18.w,
              height: 18.w,
              colorFilter: ColorFilter.mode(
                selected == 'female' ? Colors.white : unselectedTint,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          segment(
            label: Translate.translate(TranslateKeys.genderPrivate, context),
            value: null,
            selected: selected == null,
            leading: Icon(
              Icons.block_rounded,
              size: 18.sp,
              color: selected == null ? Colors.white : unselectedTint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceCard({
    required String voiceId,
    required String name,
    required String subtitle,
    required String mp3Url,
  }) {
    final isSelected = selectedVoiceId == voiceId;
    final isPlaying = _playingVoiceId == voiceId;
    return GestureDetector(
      onTap: () async {
        setState(() => selectedVoiceId = voiceId);
        await _playVoicePreview(voiceId: voiceId, mp3Url: mp3Url);
      },
      child: Container(
        height: 63.h,
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          color: isSelected
              ? const Color(0xFF6D1DB8).withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              child: Icon(
                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 22.sp),
              SizedBox(width: 8.w),
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22.sp),
            ] else
              Icon(
                Icons.radio_button_unchecked_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }

  String _normalizeGender(String? rawGender) {
    final gender = (rawGender ?? '').toLowerCase();
    if (gender == 'female' || gender == 'kadin' || gender == 'kadın' || gender == 'woman') {
      return 'female';
    }
    if (gender == 'male' || gender == 'erkek' || gender == 'man') return 'male';
    return 'private';
  }

  List<String> _parseInterests(dynamic rawInterests) {
    if (rawInterests == null) return [];
    if (rawInterests is List) {
      return rawInterests.map((e) => e.toString()).toList();
    }
    if (rawInterests is String && rawInterests.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawInterests);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  Future<void> _loadRandomSystemTwoAgentTemplate({
    String? genderFilter,
    bool syncFormFields = true,
  }) async {
    if (!mounted) return;
    setState(() => _isTemplateLoading = true);
    try {
      final user = ref.read(AllControllers.userController);
      final response = await http.post(
        Uri.parse('${AppConstants.baseURL}${AppConstants.systemAgents}'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': user?.token ?? '',
          'x-refresh-token': user?.refreshToken ?? '',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('System agents request failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('System agents response is not a list');
      }

      final allAgents = decoded
          .whereType<Map>()
          .map((element) => AgentModel.fromMap(Map<String, dynamic>.from(element)))
          .toList();

      var systemTwoAgents =
          allAgents.where((agent) => agent.system == 2).toList();
      if (genderFilter != null && genderFilter.isNotEmpty) {
        final normalized = _normalizeGender(genderFilter);
        if (normalized != 'private') {
          final filteredByGender = systemTwoAgents
              .where((agent) =>
                  _normalizeGender(agent.gender) == normalized)
              .toList();
          if (filteredByGender.isNotEmpty) {
            systemTwoAgents = filteredByGender;
          }
        }
      }
      if (systemTwoAgents.isEmpty) {
        throw Exception('No system==2 agents found');
      }

      final randomAgent =
          systemTwoAgents[Random().nextInt(systemTwoAgents.length)];
      ref
          .read(AllControllers.agentsProfileViewController.notifier)
          .changeAgentModel(randomAgent);

      if (!mounted) return;
      setState(() {
        selectedPhotoUrl = randomAgent.photoURL;
        if (syncFormFields) {
          ageController.text = randomAgent.age.toString();
          selectedInterests = _parseInterests(randomAgent.interests);
        }
      });
    } catch (e) {
      log('❌ [CREATE AGENT] system==2 template load failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Translate.translate(TranslateKeys.agentCreateFailed, context),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isTemplateLoading = false);
    }
  }

  Future<void> _loadVoices() async {
    if (!mounted) return;
    setState(() {
      _isVoicesLoading = true;
      _voiceLoadError = null;
    });

    try {
      final user = ref.read(AllControllers.userController);
      final http.Response response = await http.get(
        Uri.parse('${AppConstants.baseURL}${AppConstants.voicesList}'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': user?.token ?? '',
          'x-refresh-token': user?.refreshToken ?? '',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Voices request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final voicesJson = (data['voices'] as List<dynamic>? ?? []);
      final voices = voicesJson
          .whereType<Map>()
          .map((e) => _VoiceOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        _allVoices = voices;
        _applyVoicesForGender();
        _isVoicesLoading = false;
      });
    } catch (e) {
      log('❌ [EDIT AGENT] Voice list load failed: $e');
      if (!mounted) return;
      setState(() {
        _isVoicesLoading = false;
        _voiceLoadError = 'failed';
      });
    }
  }

  void _applyVoicesForGender() {
    if (_allVoices.isEmpty) {
      _filteredVoices = [];
      return;
    }
    final gender = _normalizeGender(selectedGender);
    _filteredVoices =
        gender == 'private' ? <_VoiceOption>[] : _allVoices.where((v) => v.gender == gender).toList();

    final hasSelectedVoice = selectedVoiceId != null &&
        _filteredVoices.any((voice) => voice.elevenlabsId == selectedVoiceId);
    if (!hasSelectedVoice) {
      selectedVoiceId =
          _filteredVoices.isNotEmpty ? _filteredVoices.first.elevenlabsId : null;
    }
  }

  List<Widget> _buildVoiceCards() {
    return List<Widget>.generate(_filteredVoices.length, (index) {
      final voice = _filteredVoices[index];
      final subtitle = voice.gender == 'female'
          ? Translate.translate(TranslateKeys.editCharacterVoiceFemale, context)
          : Translate.translate(TranslateKeys.editCharacterVoiceMale, context);
      return Padding(
        padding: EdgeInsets.only(bottom: index == _filteredVoices.length - 1 ? 0 : 10.h),
        child: _voiceCard(
          voiceId: voice.elevenlabsId,
          name: voice.name,
          subtitle: subtitle,
          mp3Url: voice.mp3Url,
        ),
      );
    });
  }

  Future<void> _playVoicePreview({
    required String voiceId,
    required String mp3Url,
  }) async {
    if (mp3Url.isEmpty) {
      await _previewPlayer.stop();
      if (!mounted) return;
      setState(() => _playingVoiceId = null);
      return;
    }

    try {
      if (_playingVoiceId == voiceId) {
        await _previewPlayer.stop();
        if (!mounted) return;
        setState(() => _playingVoiceId = null);
        return;
      }

      await _previewPlayer.stop();
      await _previewPlayer.play(UrlSource(mp3Url));
      if (!mounted) return;
      setState(() => _playingVoiceId = voiceId);

      _previewPlayer.onPlayerComplete.first.then((_) {
        if (!mounted) return;
        if (_playingVoiceId == voiceId) {
          setState(() => _playingVoiceId = null);
        }
      });
    } catch (e) {
      log('❌ [EDIT AGENT] Voice preview play failed: $e');
      if (!mounted) return;
      setState(() => _playingVoiceId = null);
    }
  }

  Widget _voiceErrorWidget() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: _sectionDecoration(),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white70, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              Translate.translate(TranslateKeys.editCharacterVoicesLoadFailed, context),
              style: GoogleFonts.quicksand(
                color: Colors.white70,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadVoices,
            child: Text(
              Translate.translate(TranslateKeys.retry, context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyVoiceWidget() {
    final normalizedGender = _normalizeGender(selectedGender);
    final message = normalizedGender == 'private'
        ? Translate.translate(TranslateKeys.editCharacterSelectGenderForVoices, context)
        : Translate.translate(TranslateKeys.editCharacterNoVoiceForGender, context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: _sectionDecoration(),
      child: Text(
        message,
        style: GoogleFonts.quicksand(
          color: Colors.white70,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

