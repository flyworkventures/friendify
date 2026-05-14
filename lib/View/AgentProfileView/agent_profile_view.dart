import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
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
  int? _selectedPhotoAgentId;
  String? _selectedPhotoUrl;
  final PageController _photoPageController = PageController();
  Timer? _photoAutoTimer;
  int _currentPhotoIndex = 0;
  List<String> _carouselPhotos = const [];

  @override
  void initState() {
    super.initState();
    init();
    _loadSelectedPhoto();
  }

  @override
  void dispose() {
    _photoAutoTimer?.cancel();
    _photoPageController.dispose();
    super.dispose();
  }

  void _syncCarouselPhotos(List<String> photos) {
    final isSame = photos.length == _carouselPhotos.length &&
        () {
          for (var i = 0; i < photos.length; i++) {
            if (photos[i] != _carouselPhotos[i]) return false;
          }
          return true;
        }();
    if (isSame) return;
    _carouselPhotos = photos;
    _currentPhotoIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_photoPageController.hasClients) {
        _photoPageController.jumpToPage(0);
      }
      _restartPhotoAutoTimer();
    });
  }

  void _restartPhotoAutoTimer() {
    _photoAutoTimer?.cancel();
    if (_carouselPhotos.length < 2) return;
    _photoAutoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (!_photoPageController.hasClients) return;
      if (_carouselPhotos.length < 2) return;
      final nextIndex = (_currentPhotoIndex + 1) % _carouselPhotos.length;
      _photoPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  List<String> _buildCarouselPhotos(AgentModel agent, String mainPhotoUrl) {
    final ordered = <String>[];
    final seen = <String>{};

    void addUrl(String? url) {
      if (url == null) return;
      final trimmed = url.trim();
      if (trimmed.isEmpty) return;
      if (!seen.add(trimmed)) return;
      ordered.add(trimmed);
    }

    addUrl(mainPhotoUrl);
    for (final url in agent.photoURLs) {
      addUrl(url);
    }
    addUrl(agent.photoURL);
    return ordered;
  }


  init() {
    AgentModel? agent = ref
        .read(AllControllers.agentsProfileViewController)
        .agent;
    List<String> interest = List.from(jsonDecode(agent?.interestsType));
    for (var element in interest) {
      icons.add(
        interestIcon(element, size: 18, color: MyColors.purple, style: HeroIconStyle.outline),
      );
      setState(() {});
    }
  }

  Future<void> _loadSelectedPhoto() async {
    final agent = ref.read(AllControllers.agentsProfileViewController).agent;
    if (agent == null) return;
    final savedPhotoUrl = await LocalService.getSelectedAgentPhoto(agent.id);
    if (!mounted) return;
    setState(() {
      _selectedPhotoAgentId = agent.id;
      _selectedPhotoUrl = savedPhotoUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    AgentModel? agent = ref
        .watch(AllControllers.agentsProfileViewController)
        .agent;
    if (agent == null) {
      return BackgroundWidget(
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: SizedBox.shrink(),
        ),
      );
    }
    final userId = ref.read(AllControllers.userController)?.id?.toString();

    // Kontrol: Kullanıcının kendi karakteri mi?
    final bool isOwnAgent = agent.system == 0 && agent.creatorId == userId;
    if (_selectedPhotoAgentId != agent.id) {
      _loadSelectedPhoto();
    }
    final agentPhotoUrl = _selectedPhotoAgentId == agent.id
        ? (_selectedPhotoUrl ?? agent.photoURL)
        : agent.photoURL;
    final carouselPhotos = _buildCarouselPhotos(agent, agentPhotoUrl);
    _syncCarouselPhotos(carouselPhotos);

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Text(
            Translate.translate("agent_profile_title", context),
            style: GoogleFonts.quicksand(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            onPressed: () => navigatorKey.currentState?.pop(),
            icon: Icon(CupertinoIcons.back, color: Colors.white),
          ),
          actions: [
            if (isOwnAgent)
              IconButton(
                onPressed: _confirmAndDeleteAgent,
                icon: const Icon(
                  CupertinoIcons.delete_solid,
                  color: Colors.redAccent,
                ),
                tooltip: Translate.translate(TranslateKeys.delete, context),
              ),
          ],
        ),

        body: Padding(
          padding: const EdgeInsets.all(20).copyWith(top: 0),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      //    _showFullScreenImage(context, agent.photoURL);
                    },
                    child: Container(
                      height: 610.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadiusGeometry.circular(16),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadiusGeometry.circular(16),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width,
                              height: double.infinity,
                              child: carouselPhotos.isEmpty
                                  ? Container(
                                      color: Colors.grey[300],
                                      child: Icon(Icons.person, size: 80),
                                    )
                                  : PageView.builder(
                                      controller: _photoPageController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: carouselPhotos.length,
                                      onPageChanged: (index) {
                                        setState(() {
                                          _currentPhotoIndex = index;
                                        });
                                        _restartPhotoAutoTimer();
                                      },
                                      itemBuilder: (context, index) {
                                        return CachedNetworkImage(
                                          width: MediaQuery.sizeOf(context).width,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          imageUrl: carouselPhotos[index],
                                          placeholder: (context, url) =>
                                              Shimmer.fromColors(
                                            baseColor: Colors.grey[300]!,
                                            highlightColor: Colors.grey[100]!,
                                            child: Container(
                                              width: MediaQuery.sizeOf(context).width,
                                              height: 336.h,
                                              color: Colors.white,
                                            ),
                                          ),
                                          errorWidget:
                                              (context, url, error) => Container(
                                            width: MediaQuery.sizeOf(context).width,
                                            height: 336.h,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.person, size: 80),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),

                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                              ).copyWith(bottom: 20).r,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16).r,
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 5.5,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 179.h,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ).copyWith(right: 0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16).r,
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: 21.h,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            children:
                                                (List.from(
                                                      jsonDecode(
                                                        agent.interests,
                                                      ),
                                                    ))
                                                    .map(
                                                      (a) => interestWidget(a),
                                                    )
                                                    .toList(),
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,

                                          children: [
                                            Text(
                                              agent.name,
                                              style: GoogleFonts.quicksand(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20.sp,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            onlineWidget(),
                                          ],
                                        ),
                                        SizedBox(height: 5.h),
                                        Text(
                                          agent.character,
                                          style: GoogleFonts.quicksand(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14.sp,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 3,
                                        ),
                                        SizedBox(height: 10.h),
                                        GestureDetector(
                                          onTap: () {
                                            navigatorKey.currentState
                                                ?.pushNamed("/editAgentView");
                                          },
                                          child: Container(
                                            margin: EdgeInsets.only(right: 20),
                                            width: MediaQuery.sizeOf(
                                              context,
                                            ).width,
                                            height: 36.h,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(50.r),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  "assets/icons/edit.svg",
                                                ),
                                                SizedBox(width: 10.w),
                                                Text(
                                                  Translate.translate(
                                                    "edit",
                                                    context,
                                                  ),
                                                  style: GoogleFonts.quicksand(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              ],
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
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      callButton(agent),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: MyGradientButton(
                          onTap: () async {
                            await ref
                                .read(
                                  AllControllers
                                      .agentsProfileViewController
                                      .notifier,
                                )
                                .startVideoCall(agent);
                          },
                          radius: BorderRadius.circular(50).r,
                          size: Size(200.w, 48.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset("assets/icons/vieo_call.svg"),
                              SizedBox(width: 10.w),
                              Text(
                                Translate.translate(
                                  "agent_profile_video_call",
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      messageButton(agent),
                    ],
                  ),

                ],
              ),

              if (ref
                      .watch(AllControllers.agentsProfileViewController)
                      .loadingScreen ==
                  true) ...[
                Container(
                  width: MediaQuery.sizeOf(context).width,
                  height: MediaQuery.sizeOf(context).height,
                  color: Colors.black.withValues(alpha: 0.2),
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
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget callButton(AgentModel? agent) {
    return GestureDetector(
      onTap: () async {
        if (agent == null) return;
        await ref
            .read(
              AllControllers
                  .agentsProfileViewController
                  .notifier,
            )
            .startVoiceCall(agent);
      },
      child: Container(
        width: 48.r,
        height: 48.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          color: Colors.black.withValues(alpha: 0.2),
        ),
        child: Center(child: SvgPicture.asset("assets/icons/call.svg")),
      ),
    );
  }

  Widget messageButton(AgentModel? agent) {
    return GestureDetector(
      onTap: () async {
        if (agent == null) return;
        await ref
            .read(
              AllControllers
                  .agentsProfileViewController
                  .notifier,
            )
            .startChat(agent);
      },
      child: Container(
        width: 48.r,
        height: 48.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          color: Colors.black.withValues(alpha: 0.2),
        ),
        child: Center(child: SvgPicture.asset("assets/icons/messages-2.svg")),
      ),
    );
  }

  Widget onlineWidget() {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: Color(0xff34C759),
            borderRadius: BorderRadius.circular(20).r,
          ),
        ),
        SizedBox(width: 3.w),
        Text(
          Translate.translate("agent_profile_online", context),
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.person, size: 100, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget interestWidget(String interest) {
    return Container(
      height: 21.h,
      margin: EdgeInsets.only(right: 5).r,
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10).r,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30).r,
      ),
      child: Text(
        interest,
        style: GoogleFonts.quicksand(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteAgent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          Translate.translate(
            TranslateKeys.delete,
            context,
          ),
        ),
        content: Text(
          Translate.translate(
            "agent_profile_delete_character_confirmation",
            context,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              Translate.translate(
                TranslateKeys.cancel,
                context,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              Translate.translate(
                TranslateKeys.delete,
                context,
              ),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(
            AllControllers
                .agentsProfileViewController
                .notifier,
          )
          .deleteAgent();
    }
  }
}
