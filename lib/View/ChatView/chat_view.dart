import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/message_model.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/View/FreeTrialActivatedView/free_trial_activated_view.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:shimmer/shimmer.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _scrollController = ScrollController();
  Timer? timer;
  int? _previousMessageCount = 0; // Önceki mesaj sayısını takip et
  int? _currentlyPlayingMessageId; // Şu anda oynatılan mesajın ID'si
  // Global audio player - tüm sesli mesajlar için tek bir player kullan
  final ap.AudioPlayer _globalAudioPlayer = ap.AudioPlayer();
  final ap.AudioPlayer _ttsPlayer = ap.AudioPlayer();
  // TextField'ın focus node'unu saklamak için
  final FocusNode _textFieldFocusNode = FocusNode();
  ChatState? _previousChatState;
  Timer? _recordingUiTimer;
  int _recordingUiSeconds = 0;
  bool _onboardingFunnelActive = false;
  bool _showOnboardingVideoCta = false;
  int? _localPhotoAgentId;
  String? _localAgentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadLocalAgentPhoto();
    getMessages().then((_) => startStream());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOnboardingFunnelState();
  }

  Future<void> _loadLocalAgentPhoto() async {
    final agent = ref.read(AllControllers.chatViewController).agent;
    if (agent == null) return;
    await _loadLocalAgentPhotoFor(agent.id);
  }

  Future<void> _loadLocalAgentPhotoFor(int agentId) async {
    final savedPhotoUrl = await LocalService.getSelectedAgentPhoto(agentId);
    if (!mounted) return;
    setState(() {
      _localPhotoAgentId = agentId;
      _localAgentPhotoUrl = savedPhotoUrl;
    });
  }

  String _agentPhotoUrl(ChatScreenViewModel controller) {
    final agent = controller.agent;
    if (agent == null) return "";
    if (_localPhotoAgentId == agent.id &&
        _localAgentPhotoUrl != null &&
        _localAgentPhotoUrl!.trim().isNotEmpty) {
      return _localAgentPhotoUrl!;
    }
    return agent.photoURL;
  }

  bool _onboardingStateLoaded = false;

  void _loadOnboardingFunnelState() {
    if (_onboardingStateLoaded) return;
    _onboardingStateLoaded = true;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    var funnel = routeArgs is Map && routeArgs["onboardingFunnel"] == true;

    void applyFunnel(bool active) {
      if (!mounted) return;
      setState(() {
        _onboardingFunnelActive = active;
        if (!active) {
          _showOnboardingVideoCta = false;
        }
      });
    }

    applyFunnel(funnel);

    // OnboardingDemoChatView önce prefs yazar; rota argümanı kaçarsa yedek.
    if (!funnel) {
      SharedPreferences.getInstance().then((prefs) {
        if (!mounted) return;
        final fromPrefs = LocalService(prefs: prefs).isOnboardingFunnelActive();
        if (fromPrefs) {
          setState(() => _onboardingFunnelActive = true);
        }
      });
    }
  }

  /// Onboarding video kapısı: deneme yoksa [FreeTrialActivated] atlanır, doğrudan login/sonraki adım.
  Future<void> _completeOnboardingVideoGateAndNavigate({
    required String postAuthAction,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    const forceLogoutToLogin = true;
    await localService.setPostAuthAction(postAuthAction);
    await localService.setOnboardingVideoGatePending(false);
    await localService.setOnboardingFunnelActive(false);
    if (!mounted) return;

    final u = ref.read(AllControllers.userController);
    if (!PremiumService.hasActiveFreeTrialMembership(u)) {
      await FreeTrialActivatedView.applyPostOnboardingTrialRouting(
        ref: ref,
        context: context,
        forceLogoutToLogin: forceLogoutToLogin,
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/freeTrialActivated',
      (route) => false,
      arguments: {
        "forceLogoutToLogin": forceLogoutToLogin,
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _scrollController.dispose();
    // Sayfadan çıkınca tüm oynatılan sesleri durdur
    _globalAudioPlayer.stop();
    _globalAudioPlayer.dispose();
    _ttsPlayer.stop();
    _ttsPlayer.dispose();
    _textFieldFocusNode.dispose();
    _currentlyPlayingMessageId = null;
    _recordingUiTimer?.cancel();
    super.dispose();
  }

  void startStream() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => listenMessages());
  }

  Future<void> getMessages() async {
    await ref.read(AllControllers.chatViewController.notifier).getMessages();
    _evaluateOnboardingVideoCta();
    scrollToBottom();
    // İlk yüklemede mesaj sayısını kaydet
    final messages = ref.read(AllControllers.chatViewController).messages;
    _previousMessageCount = messages?.length ?? 0;
    _previousChatState = ref.read(AllControllers.chatViewController).chatState;
  }

  Future<void> listenMessages() async {
    final previousCount = _previousMessageCount ?? 0;
    final previousChatState = _previousChatState ?? ChatState.normal;
    await ref.read(AllControllers.chatViewController.notifier).listenMessages();
    _evaluateOnboardingVideoCta();

    // Mesaj sayısını kontrol et
    final messages = ref.read(AllControllers.chatViewController).messages;
    final currentCount = messages?.length ?? 0;

    // Yeni mesaj geldi mi kontrol et
    if (currentCount > previousCount) {
      // Yeni mesaj geldiğinde her zaman scroll yap
      scrollToBottom();
    }
    final currentChatState = ref
        .read(AllControllers.chatViewController)
        .chatState;
    if (currentChatState == ChatState.botWriting &&
        previousChatState != ChatState.botWriting) {
      scrollToBottom();
    }

    _previousMessageCount = currentCount;
    _previousChatState = currentChatState;
  }

  Future<void> sendMessage() async {
    if (_onboardingFunnelActive && _showOnboardingVideoCta) {
      return;
    }
    await ref.read(AllControllers.chatViewController.notifier).sendMessage();
    _evaluateOnboardingVideoCta();
    // Kullanıcı mesaj attığında her zaman aşağı scroll yap
    scrollToBottom();
  }

  void _evaluateOnboardingVideoCta() {
    if (!_onboardingFunnelActive) return;
    final messages = ref.read(AllControllers.chatViewController).messages ?? [];
    final userMessageCount = messages.where((m) => m.sender == "user").length;
    final shouldShow = userMessageCount >= 4;
    if (!mounted || shouldShow == _showOnboardingVideoCta) return;
    // Deneme/premium olsa da 4. kullanıcı mesajından sonra aynı onboarding
    // adımı (video CTA); AppBar yalnızca _onboardingFunnelActive ile gizli kalır.
    setState(() => _showOnboardingVideoCta = shouldShow);
  }

  Future<void> _showOnboardingGateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),
              Center(
                child: Container(
                  width: 33.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Color(0xff313131),
                    borderRadius: BorderRadius.circular(40).r,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                width: double.infinity,
                height: 53.h,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Row(
                  children: [
                    Text("🔒"),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                          ),
                          children: [
                            TextSpan(
                              text: Translate.translate(
                                "video_gate_limit_prefix",
                                context,
                              ),
                            ),
                            TextSpan(
                              text: Translate.translate(
                                "video_gate_limit_free_messages",
                                context,
                              ),
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: Translate.translate(
                                "video_gate_limit_suffix",
                                context,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                height: 26.h,
                width: 148.w,
                margin: EdgeInsets.only(left: 15.r),
                decoration: BoxDecoration(
                  color: Color(0xffFF2B00).withValues(alpha: 0.2),
                  border: Border.all(color: Color(0xff9D3838)),
                  borderRadius: BorderRadius.circular(40).r,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: Container(
                        width: 7,
                        height: 7,
                        color: Color(0xffF44336),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate("video_gate_live_now", context),
                      style: GoogleFonts.quicksand(
                        color: Color(0xffF68178),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Text(
                  Translate.translate("video_gate_waiting_on_call", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(width: 7, height: 7, color: Color(0xffAB10E2)),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate("video_gate_benefit_no_limits_title", context),
                      style: GoogleFonts.quicksand(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      Translate.translate("video_gate_benefit_no_limits_suffix", context),
                      style: GoogleFonts.quicksand(color: Color(0xff777777), fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(width: 7, height: 7, color: Color(0xffAB10E2)),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate("video_gate_benefit_video_calls_title", context),
                      style: GoogleFonts.quicksand(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      Translate.translate("video_gate_benefit_video_calls_suffix", context),
                      style: GoogleFonts.quicksand(color: Color(0xff777777), fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(width: 7, height: 7, color: Color(0xffAB10E2)),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate("video_gate_benefit_deeper_title", context),
                      style: GoogleFonts.quicksand(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      Translate.translate("video_gate_benefit_deeper_suffix", context),
                      style: GoogleFonts.quicksand(color: Color(0xff777777), fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              MyGradientButton(
                margin: EdgeInsets.only(left: 15.r, right: 15.r),
                onTap: () async {
                  await _completeOnboardingVideoGateAndNavigate(
                    postAuthAction: 'go_premium',
                  );
                },
                radius: BorderRadius.circular(30.r),
                size: Size(double.infinity, 50.h),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HeroIcon(HeroIcons.sparkles, size: 16.w, color: Colors.white, style: HeroIconStyle.solid),
                      SizedBox(width: 8.w),
                      Text(
                        Translate.translate("video_gate_answer_call_premium", context),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await _completeOnboardingVideoGateAndNavigate(
                      postAuthAction: 'continue_normal',
                    );
                  },
                  child: Text(
                    Translate.translate("video_gate_not_now", context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white70,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        );
      },
    );
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// URL regex pattern - http, https, www ile başlayan veya domain içeren linkleri yakalar
  static final RegExp _urlRegex = RegExp(
    r'(?:(?:https?|ftp):\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
    caseSensitive: false,
  );

  /// Mesaj metnindeki linkleri tespit edip tıklanabilir ve bold yapar
  Widget _buildTextWithLinks(String text, Color defaultColor) {
    final List<TextSpan> spans = [];
    final textStyle = GoogleFonts.poppins(color: defaultColor, fontSize: 14.sp);
    final linkStyle = GoogleFonts.poppins(
      color: defaultColor,
      fontSize: 14.sp,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );

    int lastIndex = 0;
    for (final match in _urlRegex.allMatches(text)) {
      // Match'ten önceki normal metin
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: textStyle,
          ),
        );
      }

      // Link metni
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              String urlToLaunch = url;
              // Eğer http/https yoksa ekle
              if (!urlToLaunch.startsWith('http://') &&
                  !urlToLaunch.startsWith('https://')) {
                urlToLaunch = 'https://$urlToLaunch';
              }

              try {
                final uri = Uri.parse(urlToLaunch);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                print('Error launching URL: $e');
              }
            },
        ),
      );

      lastIndex = match.end;
    }

    // Kalan normal metin
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: textStyle));
    }

    // Eğer hiç link yoksa normal Text döndür
    if (spans.isEmpty || !_urlRegex.hasMatch(text)) {
      return Text(text, style: textStyle);
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showGalleryPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        Widget attachmentItem({
          required String icon,
          required String label,
          required Color bgColor,
          required VoidCallback onTap,
        }) {
          return GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                    child: Center(child: SvgPicture.asset(icon,width: 24.w,height: 24.h,)),
                
                ),
                SizedBox(height: 7.h),
                Text(
                  label,
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFF050505),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      Translate.translate("chat_attachment_title", context),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    attachmentItem(
                      icon: "assets/icons/gallery.svg",
                      label: Translate.translate("gallery", context),
                      bgColor: const Color(0xFF0B3B80),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await ref
                            .read(AllControllers.chatViewController.notifier)
                            .pickImage();
                      },
                    ),
                    SizedBox(width: 24.w),
                    attachmentItem(
                      icon: "assets/icons/camera.svg",
                      label: Translate.translate("camera", context),
                      bgColor: const Color(0xFFC89A0A),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await ref
                            .read(AllControllers.chatViewController.notifier)
                            .pickImageFromCamera();
                      },
                    ),
                    SizedBox(width: 24.w),
                    attachmentItem(
                      icon: "assets/icons/document.svg",
                      label: Translate.translate(
                        "document",
                        context,
                      ),
                      bgColor: const Color(0xFF6FA31E),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        ref
                            .read(AllControllers.chatViewController.notifier)
                            .pickAndSendPdf();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(AllControllers.chatViewController);
    final messages = controller.messages ?? [];
    final agentId = controller.agent?.id;
    if (agentId != null && _localPhotoAgentId != agentId) {
      _loadLocalAgentPhotoFor(agentId);
    }
    final agentPhotoUrl = _agentPhotoUrl(controller);

    return PopScope(
      canPop: !_onboardingFunnelActive,
      child: BackgroundWidget(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
          leading: _onboardingFunnelActive
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(CupertinoIcons.back, color: Colors.white),
                ),
          leadingWidth: _onboardingFunnelActive ? 0 : null,
          titleSpacing: _onboardingFunnelActive ? 0 : null,
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _showFullScreenImage(
                    context,
                    agentPhotoUrl,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40.r),
                  child: CachedNetworkImage(
                    imageUrl: agentPhotoUrl,
                    width: 40.w,
                    height: 40.w,
                    alignment: Alignment(0, -1),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40.w,
                      height: 40.w,
                      color: Colors.grey[300],
                      child: Icon(Icons.person, size: 25),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(AllControllers.agentsViewController.notifier)
                          .pushAgentView(controller.agent!);
                    },
                    child: Text(
                      controller.agent?.name ?? "",
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (controller.chatState == ChatState.botWriting)
                    Text(
                      Translate.translate("typing", context),
                      style: GoogleFonts.quicksand(
                        color: Colors.grey,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (controller.chatState == ChatState.botAudioRecording)
                    Text(
                      Translate.translate("recording_audio", context),
                      style: GoogleFonts.quicksand(
                        color: Colors.grey,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: _onboardingFunnelActive
              ? []
              : [
                  IconButton(
                    onPressed: () async {
                      timer?.cancel();
                      await navigatorKey.currentState?.pushNamed("/voiceCallView");
                      if (!mounted) return;
                      startStream();
                    },
                    icon: SvgPicture.asset(
                      "assets/icons/call.svg",
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      timer?.cancel();
                      await navigatorKey.currentState?.pushNamed("/videoCallView");
                      if (!mounted) return;
                      startStream();
                    },
                    icon: SvgPicture.asset("assets/icons/vieo_call.svg"),
                  ),
                ],
        ),

        // --- BODY ---
        body: SafeArea(
          child: Column(
            children: [
              // Mesaj Listesi
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    vertical: 15.h,
                    horizontal: 10.w,
                  ),
                  itemCount:
                      _getItemCount(messages) +
                      (controller.chatState == ChatState.botWriting ? 1 : 0),
                  itemBuilder: (context, index) {
                    final baseItemCount = _getItemCount(messages);
                    if (controller.chatState == ChatState.botWriting &&
                        index == baseItemCount) {
                      return _buildTypingIndicator(controller);
                    }

                    final item = _getItemAtIndex(messages, index);
                    if (item is String) {
                      // Tarih başlığı
                      return _buildDateHeader(item);
                    } else {
                      // Mesaj
                      final msg = item as MessageModel;
                      return Align(
                        alignment: msg.sender == "user"
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _chatBubble(msg),
                      );
                    }
                  },
                ),
              ),

              // Yazı alanı
              if (_onboardingFunnelActive && _showOnboardingVideoCta)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                  child: MyGradientButton(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final localService = LocalService(prefs: prefs);
                      await localService.setOnboardingVideoGatePending(true);
                      timer?.cancel();
                      final result = await navigatorKey.currentState?.pushNamed(
                        "/videoCallView",
                      );
                      if (!mounted) return;
                      if (result == "onboarding_gate_expired") {
                        _showOnboardingGateSheet();
                        return;
                      }
                      startStream();
                    },
                    radius: BorderRadius.circular(40.r),
                    size: Size(double.infinity, 48.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                       SvgPicture.asset("assets/icons/videocallmagic.svg"),
                        SizedBox(width: 8.w),
                        Text(
                          Translate.translate("chat_join_video_call", context),
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _messageInput(controller.responseWaiting!),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _chatBubble(MessageModel message) {
    if (message.messageType == "text") {
      final isUser = message.sender == "user";
      return Column(
        children: [
          if (isUser)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onLongPressStart: null,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  margin: EdgeInsets.only(
                    top: 8.h,
                    bottom: 8.h,
                    right: 12.w,
                    left: 50.w,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xffAB10E2)),
                    color: const Color(0xffAB10E2).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16).r,
                      topRight: const Radius.circular(0).r,
                      bottomLeft: const Radius.circular(16).r,
                      bottomRight: const Radius.circular(16),
                    ),
                  ),
                  child: _buildTextWithLinks(message.message, Colors.white),
                ),
              ),
            )
          else
            Container(
              margin: EdgeInsets.only(
                top: 8.h,
                bottom: 8.h,
                left: 12.w,
                right: 50.w,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _buildBotAvatar(),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: GestureDetector(
                      onLongPressStart: (details) => _showMessageActionMenu(
                        globalPosition: details.globalPosition,
                        messageText: message.message,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          color: Colors.black.withValues(alpha: 0.4),
                           borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(0).r,
                            topRight: const Radius.circular(16).r,
                            bottomLeft: const Radius.circular(16).r,
                            bottomRight: const Radius.circular(16).r,
                          ),
                        ),
                        child: _buildTextWithLinks(
                          message.message,
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else if (message.messageType == "voice") {
      return voiceBuble(message);
    } else if (message.messageType == "image") {
      return imageBubble(message);
    } else if (message.messageType == "pdf") {
      return _pdfBubble(message);
    } else {
      return voiceBuble(message);
    }
  }

  Widget _pdfBubble(MessageModel message) {
    final isUser = message.sender == "user";
    final content = message.message?.toString() ?? "";
    final lines = content.split('\n');
    String fileName = "Document.pdf";
    String? pdfUrl;

    for (final line in lines) {
      if (line.startsWith("[PDF] ")) {
        fileName = line.replaceFirst("[PDF] ", "").trim();
      } else if (line.startsWith("http")) {
        pdfUrl = line.trim();
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildBotAvatar(),
          if (!isUser) SizedBox(width: 8.w),
          GestureDetector(
            onTap: () {
              if (pdfUrl != null) {
                launchUrl(Uri.parse(pdfUrl));
              }
            },
            child: Container(
              constraints: BoxConstraints(maxWidth: 260.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
 
                borderRadius: BorderRadius.circular(16.r).copyWith(topRight: Radius.circular(0)),
                  border: Border.all(color: const Color(0xffAB10E2)),
                    color: const Color(0xffAB10E2).withValues(alpha: 0.5)
                ),
              
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                 SvgPicture.asset(
                        "assets/icons/file.svg",
                        width: 20.w,
                        height: 20.h,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                  SizedBox(width: 10.w),
                  Flexible(
                    child: Text(
                      fileName,
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageActionMenu({
    required Offset globalPosition,
    required String messageText,
  }) async {
    final selectedAction = await showMenu<String>(
      context: context,
      color: const Color(0xff242424),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        MediaQuery.of(context).size.width - globalPosition.dx,
        MediaQuery.of(context).size.height - globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'speak',
          child: SizedBox(
            width: 150.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Seslendir', style: TextStyle(color: Colors.white)),
                Icon(Icons.volume_up_outlined, color: Colors.white),
              ],
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: SizedBox(
            width: 150.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Kopyala', style: TextStyle(color: Colors.white)),
                Icon(Icons.copy_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );

    if (!mounted || selectedAction == null) return;

    if (selectedAction == 'copy') {
      await Clipboard.setData(ClipboardData(text: messageText));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mesaj kopyalandi')));
      return;
    }

    await _speakMessageWithAgentVoice(messageText);
  }

  Future<void> _speakMessageWithAgentVoice(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final apiKey = AppConstants.elevenLabsApiKey.trim();
    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ElevenLabs API key bulunamadi')),
      );
      return;
    }

    final agent = ref.read(AllControllers.chatViewController).agent;
    final voiceId = (agent?.voiceId?.trim().isNotEmpty ?? false)
        ? agent!.voiceId!.trim()
        : AppConstants.elevenLabsVoiceId;
    final ttsUrl = Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$voiceId',
    );

    try {
      final response = await http.post(
        ttsUrl,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': trimmed,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {'stability': 0.4, 'similarity_boost': 0.8},
        }),
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ses üretilemedi (${response.statusCode})')),
        );
        return;
      }

      final Uint8List audioBytes = response.bodyBytes;
      if (audioBytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ses verisi bos dondu')));
        return;
      }

      await _ttsPlayer.stop();
      await _ttsPlayer.play(ap.BytesSource(audioBytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Seslendirme hatasi: $e')));
    }
  }

  Widget imageBubble(MessageModel message) {
    var json = jsonDecode(message.message);
    final imageUrl = json["imageURL"] ?? "";
    final userMessage = json["message"];
    final aiExplanation = json["aiExplanation"];

    final content = Container(
      margin: EdgeInsets.only(
        top: 8.h,
        bottom: 8.h,
        right: message.sender == "user" ? 12.w : 0,
        left: message.sender == "bot" ? 0 : 50.w,
      ),
      child: Column(
        crossAxisAlignment: message.sender == "user"
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 200.w,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 200.w,
                  height: 200.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200.w,
                height: 200.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 50.sp,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),

          // Kullanıcı mesajı varsa göster
          if (userMessage != null && userMessage.toString().isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: message.sender == "user"
                    ? MyColors.purple
                    : const Color(0xffF4F4F4),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                userMessage,
                style: GoogleFonts.poppins(
                  color: message.sender == "bot"
                      ? const Color(0xff555555)
                      : Colors.white,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],

          // AI açıklaması varsa göster (bot mesajlarında)
          if (aiExplanation != null &&
              aiExplanation.toString().isNotEmpty &&
              message.sender == "bot") ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xffF4F4F4),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                aiExplanation,
                style: GoogleFonts.poppins(
                  color: const Color(0xff555555),
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (message.sender == "bot") {
      return Container(
        margin: EdgeInsets.only(left: 12.w, right: 50.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBotAvatar(),
            SizedBox(width: 10.w),
            Expanded(child: content),
          ],
        ),
      );
    }

    return content;
  }

  Widget _buildBotAvatar() {
    final controller = ref.watch(AllControllers.chatViewController);
    final imageUrl = _agentPhotoUrl(controller);
    return ClipRRect(
      borderRadius: BorderRadius.circular(40.r),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 44.w,
        height: 44.w,
        alignment: Alignment(0, -1),
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 44.w,
          height: 44.w,
          color: Colors.grey[300],
          child: Icon(Icons.person, size: 24.sp),
        ),
      ),
    );
  }

  Widget voiceBuble(MessageModel message) {
    final json = jsonDecode(message.message);
    final audioUrl = (json["url"] ?? "").toString();

    if (message.sender == "user") {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        margin: EdgeInsets.only(top: 8.h, bottom: 8.h, right: 12.w, left: 70.w),
        decoration: BoxDecoration(
          color: MyColors.purple.withValues(alpha: 0.55),
                 borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16).r,
                            topRight: const Radius.circular(0).r,
                            bottomLeft: const Radius.circular(16).r,
                            bottomRight: const Radius.circular(16).r,
                          ),
          border: Border.all(color: MyColors.purple.withValues(alpha: 0.9)),
        ),
        child: _buildVoicePlayer(
          message.id,
          audioUrl,
          playedColor: Colors.white,
          iconColor: Colors.black,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: 8.h, bottom: 8.h, right: 12.w, left: 12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildBotAvatar(),
          SizedBox(width: 10.w),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 0.72.sw),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(0).r,
                            topRight: const Radius.circular(16).r,
                            bottomLeft: const Radius.circular(16).r,
                            bottomRight: const Radius.circular(16).r,
                          ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: _buildVoicePlayer(
                  message.id,
                  audioUrl,
                  playedColor: const Color(0xFFA214FF),
                  iconColor: Colors.black,
                  botStyle: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePlayer(
    int messageId,
    String audioUrl, {
    required Color playedColor,
    required Color iconColor,
    bool botStyle = false,
  }) {
    return _ControlledWavedAudioPlayer(
      key: ValueKey('audio_$messageId'),
      messageId: messageId,
      audioUrl: audioUrl,
      playedColor: playedColor,
      iconColor: iconColor,
      botStyle: botStyle,
      currentlyPlayingId: _currentlyPlayingMessageId,
      globalAudioPlayer: _globalAudioPlayer,
      textFieldFocusNode: _textFieldFocusNode,
      onPlayStarted: (id) {
        if (!mounted) return;
        setState(() => _currentlyPlayingMessageId = id);
      },
      onPlayStopped: (id) {
        if (!mounted) return;
        if (_currentlyPlayingMessageId == id) {
          setState(() => _currentlyPlayingMessageId = null);
        }
      },
    );
  }

  String dateParser(String date) {
    DateTime dateTime = DateTime.parse(date);
    String hour = "";
    String minute = "";
    if (dateTime.hour < 10) {
      hour = "0${dateTime.hour}";
    } else {
      hour = dateTime.hour.toString();
    }
    var x = dateTime.minute / 10;

    if (x.runtimeType.toString() == "int") {
      minute = "${dateTime.minute}0";
    } else if (dateTime.minute < 10) {
      minute = "0${dateTime.minute}";
    } else {
      minute = dateTime.minute.toString();
    }
    return "$hour:$minute";
  }

  /// Mesajları tarihlerine göre gruplar ve tarih başlıkları ekler
  int _getItemCount(List<MessageModel> messages) {
    if (messages.isEmpty) return 0;

    int count = messages.length;
    DateTime? lastDate;

    for (var msg in messages) {
      final msgDate = DateTime.parse(msg.createdAt);
      final msgDateOnly = DateTime(msgDate.year, msgDate.month, msgDate.day);

      if (lastDate == null || !_isSameDay(msgDateOnly, lastDate)) {
        count++; // Tarih başlığı için ekstra item
        lastDate = msgDateOnly;
      }
    }

    return count;
  }

  /// Belirli bir index'teki item'ı döndürür (mesaj veya tarih başlığı)
  dynamic _getItemAtIndex(List<MessageModel> messages, int index) {
    int currentIndex = 0;
    DateTime? lastDate;

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = DateTime.parse(msg.createdAt);
      final msgDateOnly = DateTime(msgDate.year, msgDate.month, msgDate.day);

      // Yeni bir gün mü?
      if (lastDate == null || !_isSameDay(msgDateOnly, lastDate)) {
        // Tarih başlığı ekle
        if (currentIndex == index) {
          return _formatDateHeader(msgDateOnly);
        }
        currentIndex++;
        lastDate = msgDateOnly;
      }

      // Mesaj ekle
      if (currentIndex == index) {
        return msg;
      }
      currentIndex++;
    }

    // Fallback (olması gerekmez ama güvenlik için)
    return messages.isNotEmpty ? messages.last : null;
  }

  /// İki tarihin aynı gün olup olmadığını kontrol eder
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Tarih başlığını formatlar (Bugün, Dün, veya tam tarih)
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (_isSameDay(dateOnly, today)) {
      return Translate.translate("today", context);
    } else if (_isSameDay(dateOnly, yesterday)) {
      return Translate.translate("yesterday", context);
    } else {
      // Tam tarih formatı
      final locale = Localizations.localeOf(context);
      if (locale.languageCode == 'tr') {
        final months = [
          'Ocak',
          'Şubat',
          'Mart',
          'Nisan',
          'Mayıs',
          'Haziran',
          'Temmuz',
          'Ağustos',
          'Eylül',
          'Ekim',
          'Kasım',
          'Aralık',
        ];
        return '${date.day} ${months[date.month - 1]} ${date.year}';
      } else {
        return DateFormat('d MMMM yyyy', 'en').format(date);
      }
    }
  }

  /// Tarih başlığı widget'ı
  Widget _buildDateHeader(String dateText) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            dateText,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ChatScreenViewModel controller) {
    final imageUrl = _agentPhotoUrl(controller);
    return Container(
      margin: EdgeInsets.only(left: 12.w, right: 50.w, top: 8.h, bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40.r),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 44.w,
              height: 44.w,
              alignment: Alignment(0, -1),
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 44.w,
                height: 44.w,
                color: Colors.grey[300],
                child: Icon(Icons.person, size: 24.sp),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const _ChatTypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _emptyChatView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(60.r),
            child: Image.asset("assets/hello.gif", width: 120.w, height: 120.h),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color(0xffF7F7F7),
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              Translate.translate(TranslateKeys.sayHi, context),
              style: GoogleFonts.quicksand(
                color: Colors.black,
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageInput(bool isLoading) {
    final controllerStream = ref
        .watch(AllControllers.chatViewController.notifier)
        .messageController;
    final chatController = ref.watch(AllControllers.chatViewController);
    final chatControllerNotifier = ref.read(
      AllControllers.chatViewController.notifier,
    );
    final onboardingLocked = _onboardingFunnelActive && _showOnboardingVideoCta;
    _syncRecordingUiState(chatController.recordState);

    // Kayıt yapılıyor veya duraklatılmış
    if (chatController.recordState == RecordState.recording ||
        chatController.recordState == RecordState.paused) {
      final isPaused = chatController.recordState == RecordState.paused;
      return Container(
        width: MediaQuery.sizeOf(context).width,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        margin: EdgeInsets.symmetric(horizontal: 15.w),
        height: 48.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF020819),
              const Color(0xFF061033),
              const Color(0xFF08164A),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (isPaused) {
                  chatControllerNotifier.resumeRecording();
                } else {
                  chatControllerNotifier.pauseRecording();
                }
              },
              child: SvgPicture.asset(
                isPaused ? "assets/icons/play.svg" : "assets/icons/stop.svg",
                width: 18,
                height: 18,
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              _formatRecordingDuration(_recordingUiSeconds),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 8.5.sp,
              ),
            ),
            SizedBox(width: 7.w),
            Expanded(
              child: AudioWaveforms(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                waveStyle: WaveStyle(
                  waveColor: isPaused ? Colors.white38 : Colors.white,
                  spacing: 2.6,
                  waveThickness: 2.2,
                  showTop: true,
                  showBottom: true,
                  extendWaveform: true,
                  showMiddleLine: false,
                ),
                size: Size(MediaQuery.sizeOf(context).width, 20.h),
                recorderController: chatControllerNotifier.recorderController,
              ),
            ),
            SizedBox(width: 6.w),
            if (isPaused)
              GestureDetector(
                onTap: () => chatControllerNotifier.cancelRecording(),
                child: SvgPicture.asset(
                  "assets/icons/trash3.svg",
                  width: 18,
                  height: 18,
                ),
              )
            else
              GestureDetector(
                onTap: () => chatControllerNotifier.stopRecordingAndSend(),
                child: HeroIcon(
                  HeroIcons.paperAirplane,
                  style: HeroIconStyle.solid,
                  size: 20.sp,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      );
    }

    // Kayıt durdurulmuş - gönderme butonu göster
    if (chatController.recordState == RecordState.stopped) {
      return Container(
        width: MediaQuery.sizeOf(context).width,
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        margin: EdgeInsets.symmetric(horizontal: 15.w),
        height: 45.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50.r),
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            // İptal butonu (sol taraf) - WhatsApp'taki gibi kırmızı X
            GestureDetector(
              onTap: () => chatControllerNotifier.cancelStoppedRecording(),
              child: Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.red, size: 20),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Center(
                child: Text(
                  Translate.translate("recording_stopped", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.black54,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),

            GestureDetector(
              onTap: () => chatControllerNotifier.sendStoppedRecording(),
              child: Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ],
        ),
      );
    }

    // Normal input (kayıt yok)
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 5.h, 16.w, 15.h),
      child: Column(
        children: [
          if (ref
                  .watch(AllControllers.chatViewController.notifier)
                  .selectedImage !=
              null) ...[
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: 60.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20).r,
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 60.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12).r,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12).r,
                      child: Image.file(
                        File(
                          ref
                              .watch(AllControllers.chatViewController.notifier)
                              .selectedImage!
                              .path,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      Translate.translate(TranslateKeys.image, context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(AllControllers.chatViewController.notifier)
                          .removeImage();
                    },
                    child: Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(50).r,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 15.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10.h),
          ],

          MyTextField(
            controller: controllerStream,
            enabled: !onboardingLocked,
            focusNode: _textFieldFocusNode,
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            hintText: "${Translate.translate(TranslateKeys.enterMessage, context)}...",
            hintStyle: GoogleFonts.quicksand(color: Colors.white),
            prefixIcon: GestureDetector(
              onTap: onboardingLocked
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      _showGalleryPopup(context);
                    },
              child: HeroIcon(
                HeroIcons.plus,
                style: HeroIconStyle.solid,
                color: Colors.white,
                size: 24,
              ),
            ),
            textStyle: GoogleFonts.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
            suffixIcon: onboardingLocked
                ? Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white70,
                    size: 22.sp,
                  )
                : AnimatedSwitcher(
                    duration: Duration(milliseconds: 50),

                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: suffixIcon(isLoading),
                  ),
          ),
        ],
      ),
    );
  }

  void _syncRecordingUiState(RecordState state) {
    if (state == RecordState.recording) {
      if (_recordingUiTimer != null) return;
      _recordingUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _recordingUiSeconds++;
        });
      });
      return;
    }
    if (state == RecordState.paused) {
      _recordingUiTimer?.cancel();
      _recordingUiTimer = null;
      return;
    }
    _recordingUiTimer?.cancel();
    _recordingUiTimer = null;
    _recordingUiSeconds = 0;
  }

  String _formatRecordingDuration(int seconds) {
    final minutePart = (seconds ~/ 60).toString().padLeft(1, '0');
    final secondPart = (seconds % 60).toString().padLeft(2, '0');
    return '$minutePart:$secondPart';
  }

  /// Mikrofon butonu - tıklayınca kayıt başlar
  Widget _buildInstagramStyleMicrophoneButton(
    ChatScreenViewController notifier,
  ) {
    return GestureDetector(
      onTap: () async {
        // Tıklayınca kayıt başlat
        debugPrint("🎤 onTap - Kayıt başlatılıyor...");
        await notifier.startRecording();
      },
      child: SvgPicture.asset("assets/icons/mic.svg"),
    );
  }

  Widget suffixIcon(bool isLoading) {
    final controllerStream = ref
        .watch(AllControllers.chatViewController.notifier)
        .messageController;
    final chatControllerNotifier = ref.read(
      AllControllers.chatViewController.notifier,
    );
    final hasImage = chatControllerNotifier.selectedImage != null;

    if (isLoading) {
      // Modern loading animasyonu - 3 nokta
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: _buildLoadingDots(),
      );
    } else {
      // Eğer resim seçilmişse VEYA mesaj yazılmışsa gönder butonu göster
      if (hasImage || controllerStream.text.trim().isNotEmpty) {
        return _buildSendButton();
      } else {
        // Ne resim ne de mesaj varsa mikrofon göster - Instagram tarzı
        return _buildInstagramStyleMicrophoneButton(chatControllerNotifier);
      }
    }
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

  /// Modern loading animasyonu - 3 nokta
  Widget _buildLoadingDots() {
    return SizedBox(width: 34.w, height: 30.h, child: _LoadingDotsWidget());
  }

  /// Modern gönder butonu
  Widget _buildSendButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: sendMessage,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40.w,
          height: 40.h,
          padding: EdgeInsets.all(8.w),
          child: HeroIcon(
            HeroIcons.paperAirplane,
            style: HeroIconStyle.solid,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.report_outlined, color: Colors.orange),
                title: Text(
                  Translate.translate(TranslateKeys.report, context),
                  style: GoogleFonts.quicksand(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  Translate.translate(
                    TranslateKeys.deleteConversation,
                    context,
                  ),
                  style: GoogleFonts.quicksand(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final TextEditingController descriptionController = TextEditingController();

    final List<String> reportReasons = [
      'inappropriate_content',
      'harassment',
      'spam',
      'violence',
      'hate_speech',
      'other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                Translate.translate(TranslateKeys.reportDialogTitle, context),
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 18.sp,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translate.translate(TranslateKeys.reportReason, context),
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(
                            Translate.translate(
                              TranslateKeys.selectReason,
                              context,
                            ),
                            style: GoogleFonts.quicksand(),
                          ),
                          value: selectedReason,
                          items: reportReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(
                                Translate.translate(reason, context),
                                style: GoogleFonts.quicksand(),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedReason = value;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      Translate.translate(
                        TranslateKeys.reportDescription,
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: Translate.translate(
                          TranslateKeys.reportDescriptionHint,
                          context,
                        ),
                        hintStyle: GoogleFonts.quicksand(
                          color: Colors.grey,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: MyColors.purple),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    Translate.translate(TranslateKeys.cancel, context),
                    style: GoogleFonts.quicksand(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                          final description = descriptionController.text.trim();
                          if (description.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  Translate.translate(
                                    TranslateKeys.reportDescriptionHint,
                                    context,
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          // Send report
                          final success = await _sendReport(
                            selectedReason!,
                            description,
                          );

                          // Close dialog first
                          if (mounted) {
                            Navigator.pop(dialogContext);
                          }

                          // Show feedback after dialog is closed
                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Translate.translate(
                                      TranslateKeys.reportSentSuccess,
                                      context,
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Translate.translate(
                                      TranslateKeys.reportSentError,
                                      context,
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    Translate.translate(TranslateKeys.sendReport, context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _sendReport(String reason, String description) async {
    return await ref
        .read(AllControllers.chatViewController.notifier)
        .sendReport(reason, description);
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

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            Translate.translate(TranslateKeys.deleteConversationTitle, context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
            ),
          ),
          content: Text(
            Translate.translate(
              TranslateKeys.deleteConversationMessage,
              context,
            ),
            style: GoogleFonts.quicksand(fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                Translate.translate(TranslateKeys.cancel, context),
                style: GoogleFonts.quicksand(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await _deleteConversation();
                navigatorKey.currentState?.pop();

                if (success) {
                  navigatorKey.currentState?.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        Translate.translate(
                          TranslateKeys.conversationDeletedError,
                          context,
                        ),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                Translate.translate(TranslateKeys.delete, context),
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _deleteConversation() async {
    return await ref
        .read(AllControllers.chatViewController.notifier)
        .deleteConversation();
  }
}

/// Loading dots animasyonu için StatefulWidget
class _LoadingDotsWidget extends StatefulWidget {
  @override
  State<_LoadingDotsWidget> createState() => _LoadingDotsWidgetState();
}

class _LoadingDotsWidgetState extends State<_LoadingDotsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final animationValue = ((_controller.value + delay) % 1.0);
            final opacity = animationValue < 0.5
                ? animationValue * 2
                : 2 - (animationValue * 2);
            final scale =
                0.7 +
                (animationValue < 0.5
                    ? animationValue * 0.6
                    : (1 - animationValue) * 0.6);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              width: 8.w * scale,
              height: 8.w * scale,
              decoration: BoxDecoration(
                color: MyColors.purple.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

class _ChatTypingDots extends StatefulWidget {
  const _ChatTypingDots();

  @override
  State<_ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<_ChatTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52.w,
      height: 16.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = (_controller.value - (index * 0.16)) % 1.0;
              final opacity = phase < 0.5 ? 0.35 + (phase * 1.3) : 1 - phase;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: opacity.clamp(0.25, 1)),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// WavedAudioPlayer widget'ını sarmalayan widget - aynı anda sadece bir sesli mesaj oynatmak için
class _ControlledWavedAudioPlayer extends StatefulWidget {
  final int messageId;
  final String audioUrl;
  final Color playedColor;
  final Color iconColor;
  final bool botStyle;
  final int? currentlyPlayingId;
  final ap.AudioPlayer globalAudioPlayer;
  final Function(int) onPlayStarted;
  final Function(int) onPlayStopped;
  final FocusNode?
  textFieldFocusNode; // TextField'ın focus node'unu saklamak için

  const _ControlledWavedAudioPlayer({
    super.key,
    required this.messageId,
    required this.audioUrl,
    required this.playedColor,
    required this.iconColor,
    required this.botStyle,
    required this.currentlyPlayingId,
    required this.globalAudioPlayer,
    required this.onPlayStarted,
    required this.onPlayStopped,
    this.textFieldFocusNode,
  });

  @override
  State<_ControlledWavedAudioPlayer> createState() =>
      _ControlledWavedAudioPlayerState();
}

class _ControlledWavedAudioPlayerState
    extends State<_ControlledWavedAudioPlayer> {
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _durationSub = widget.globalAudioPlayer.onDurationChanged.listen((value) {
      if (!mounted || widget.currentlyPlayingId != widget.messageId) return;
      setState(() => _duration = value);
    });
    _positionSub = widget.globalAudioPlayer.onPositionChanged.listen((value) {
      if (!mounted || widget.currentlyPlayingId != widget.messageId) return;
      setState(() => _position = value);
    });
    _completeSub = widget.globalAudioPlayer.onPlayerComplete.listen((_) {
      if (!mounted || widget.currentlyPlayingId != widget.messageId) return;
      widget.onPlayStopped(widget.messageId);
      setState(() => _position = Duration.zero);
    });
  }

  @override
  void didUpdateWidget(_ControlledWavedAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentlyPlayingId == widget.messageId &&
        widget.currentlyPlayingId != widget.messageId) {
      setState(() => _position = Duration.zero);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.audioUrl.trim().isEmpty) return;
    final isCurrent = widget.currentlyPlayingId == widget.messageId;
    try {
      if (isCurrent) {
        await widget.globalAudioPlayer.stop();
        widget.onPlayStopped(widget.messageId);
        if (!mounted) return;
        setState(() => _position = Duration.zero);
        return;
      }
      await widget.globalAudioPlayer.stop();
      widget.onPlayStarted(widget.messageId);
      await widget.globalAudioPlayer.play(
        ap.UrlSource(widget.audioUrl, mimeType: 'audio/mpeg'),
      );
      final duration = await widget.globalAudioPlayer.getDuration();
      if (mounted && duration != null && duration > Duration.zero) {
        setState(() => _duration = duration);
      }
    } catch (err) {
      debugPrint('Audio player error: $err');
      widget.onPlayStopped(widget.messageId);
    }
  }

  double get _progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  Widget _buildWaveBars() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Daha doğal bir waveform görünümü için simetrik desen.
        const pattern = <double>[
          0.24,
          0.34,
          0.46,
          0.60,
          0.78,
          0.52,
          0.86,
          0.66,
          0.92,
          0.58,
          0.98,
          0.70,
          1.00,
          0.72,
          0.96,
          0.62,
          0.90,
          0.56,
          0.82,
          0.48,
          0.70,
          0.42,
          0.58,
          0.36,
          0.46,
          0.30,
        ];
        final barCount = pattern.length;
        const barWidth = 2.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(barCount, (index) {
            final barHeight = (4.8.h + (pattern[index] * 10.8.h)).clamp(
              5.h,
              15.h,
            );
            final isPlayed = _progress >= ((index + 1) / barCount);
            const playedColor = Color(0xFFAB10E2);
            const unplayedColor = Color(0xFFD9D9D9);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: isPlayed ? playedColor : unplayedColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlayingThis = widget.currentlyPlayingId == widget.messageId;
    if (widget.botStyle) {
      return SizedBox(
        height: 34.h,
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 30.w,
                height: 30.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlayingThis ? Icons.pause : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 18.sp,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(child: _buildWaveBars()),
          ],
        ),
      );
    }

    return Row(
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.iconColor,
              size: 20.sp,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(child: _buildWaveBars()),
      ],
    );
  }
}
