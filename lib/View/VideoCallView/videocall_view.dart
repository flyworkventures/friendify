import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/View/FreeTrialActivatedView/free_trial_activated_view.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:record/record.dart' hide IosAudioCategory;
import 'package:rive/rive.dart' hide File;
import 'package:shared_preferences/shared_preferences.dart';

class VideocallView extends ConsumerStatefulWidget {
  const VideocallView({super.key});

  @override
  ConsumerState<VideocallView> createState() => _VideocallViewState();
}

class _VideocallViewState extends ConsumerState<VideocallView> {
  static const int _sampleRate = 16000;
  static const int _channels = 1;
  static const int _frameMs = 20;
  static const int _frameBytes =
      (_sampleRate * _channels * 2 * _frameMs) ~/ 1000; // 640
  static const int _onboardingGateDurationSeconds = 60;
  static const int _speechMinStartMs = 60;
  static const int _speechSilenceStopMs = 900;
  static const double _minVadThreshold = 120.0;
  static const double _hardVoiceThreshold = 700.0;
  static const double _noiseMultiplier = 2.2;
  static const int _bargeInMinStartMs = 260;
  static const double _bargeInEnergyMultiplier = 1.8;
  static const double _bargeInMinEnergy = 1200.0;
  static const int _ttsFeedbackGuardMs = 280;
  static const int _ttsPcmSampleRate = 24000;
  static const bool _debugLogs = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final ValueNotifier<int> _visemeNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _visemeTimeNotifier = ValueNotifier<double>(0);
  final List<int> _pcmBuffer = [];
  final Map<String, List<int>> _ttsBuffers = {};
  final Map<String, List<_TtsFrame>> _visemeBuffers = {};
  final Map<String, List<Timer>> _visemeTimers = {};
  final Map<String, bool> _visemeTimelineLastFlags = {};

  WebSocket? _socket;
  StreamSubscription? _wsSub;
  StreamSubscription<Uint8List>? _recordSub;
  Timer? _reconnectTimer;
  Timer? _playbackDoneTimer;
  bool _pcmPlayerReady = false;
  bool _ttsUsesPcm = true;
  String? _activeTtsUtteranceId;
  bool _ringbackActive = false;
  bool _isExitingCall = false;

  bool _connected = false;
  bool _serverReportedReady = false;
  bool _sessionReady = false;
  bool _avatarReadySentToServer = false;
  final Set<String> _deferredPlaybackUtterances = <String>{};
  // Streaming path: gelen PCM chunk'larını anında PCM player'a feed ettiğimiz
  // utterance'lar için toplam byte sayısı (playback_done timer'ı için).
  // _finalizeAndPlayTts bu mapte varsa replay yapmaz, sadece state finalize eder.
  final Map<String, int> _streamedUtteranceBytes = <String, int>{};
  // Streaming için utterance başlangıç zamanı — viseme schedule referansı.
  final Map<String, DateTime> _streamedUtteranceStart = <String, DateTime>{};
  bool _isMicStreaming = false;
  bool _isSpeechActive = false;
  bool _isAiSpeaking = false;
  String _turnState = "idle";
  bool _manualClose = false;
  String _status = "";
  String _userText = "";
  String _aiText = "";

  final String _sessionId = "sess-${DateTime.now().millisecondsSinceEpoch}";
  String? _currentUtteranceId;
  int _chunkSeq = 0;
  int _reqCounter = 0;
  int _reconnectAttempts = 0;
  int _voicedFrames = 0;
  int _lastVoiceMs = 0;
  int _chunkLogCounter = 0;
  int _receivedEventCounter = 0;
  int _sentEventCounter = 0;
  int _streamStartMs = 0;
  int _suppressVadUntilMs = 0;
  double _noiseFloor = 80.0;
  int _lastTtsBytes = 0;
  final Set<String> _completedTtsUtterances = <String>{};
  bool _localizedTextsInitialized = false;
  bool _sessionStartSent = false;
  bool _riveAvatarReady = false;
  List<CameraDescription> _availableCameras = [];
  CameraLensDirection _previewLensDirection = CameraLensDirection.front;
  CameraController? _cameraController;
  bool _isCameraPreviewReady = false;
  Timer? _onboardingSheetTimer;
  Timer? _riveReadyFallbackTimer;
  bool _onboardingSheetShown = false;
  Timer? _onboardingCountdownTimer;
  int _onboardingCountdownSeconds = _onboardingGateDurationSeconds;
  bool _shouldShowOnboardingGate = false;

  String _nextReq() => "r${++_reqCounter}";
  AgentModel? get _activeAgent =>
      ref.read(AllControllers.chatViewController).agent;
  int? get _activeConversationId =>
      ref.read(AllControllers.chatViewController).chatModel?.id;
  String _t(String key) => Translate.translate(key, context);
  String _fmt(String key, Map<String, String> vars) {
    var text = _t(key);
    vars.forEach((k, v) {
      text = text.replaceAll("%%$k%%", v);
    });
    return text;
  }

  String _userLine(String text) => "${_t("video_call_user_prefix")}: $text";
  String _aiLine(String text) => "${_t("video_call_ai_prefix")}: $text";
  String _localizedTurnState(String state) {
    switch (state) {
      case "listening":
        return _t("video_call_turn_listening");
      case "thinking":
        return _t("video_call_turn_thinking");
      case "speaking":
        return _t("video_call_turn_speaking");
      default:
        return _t("video_call_turn_idle");
    }
  }

  void _initLocalizedTexts() {
    _status = _t("video_call_status_connecting");
    _userText = _userLine("...");
    _aiText = _aiLine("...");
  }

  Widget _buildPhotoFallback(AgentModel? agent) {
    return agent?.photoURL.isNotEmpty == true
        ? CachedNetworkImage(
            imageUrl: agent!.photoURL,
            alignment: Alignment(0, -1),
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: Colors.white70)),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black26,
              child: const Icon(Icons.person, color: Colors.white70, size: 70),
            ),
          )
        : Container(
            color: Colors.black26,
            child: const Icon(Icons.person, color: Colors.white70, size: 70),
          );
  }

  Widget _buildAgentAvatar(AgentModel? agent) {
    final riveUrl = agent?.riveAvatar?.trim();
    if (riveUrl == null || riveUrl.isEmpty) {
      return _buildPhotoFallback(agent);
    }
    _log("Rive url used directly: $riveUrl");
    return _NetworkRiveAvatar(
      url: riveUrl,
      fallback: _buildPhotoFallback(agent),
      visemeNotifier: _visemeNotifier,
      visemeTimeNotifier: _visemeTimeNotifier,
      onReady: _onRiveAvatarReady,
    );
  }

  void _onRiveAvatarReady() {
    if (_riveAvatarReady) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _riveAvatarReady) return;
      setState(() => _riveAvatarReady = true);
      _signalAvatarReadyToServer();
      _tryActivateCallUi();
      _ensureSessionStarted("rive_ready");
      _flushDeferredAgentAudio();
    });
  }

  bool _isAvatarReadyForSession() {
    final hasRive = _activeAgent?.riveAvatar?.trim().isNotEmpty == true;
    return !hasRive || _riveAvatarReady;
  }

  void _signalAvatarReadyToServer() {
    if (_avatarReadySentToServer || !_connected) return;
    // Güvenlik kemeri: Rive avatar'lı agent için Rive gerçekten görünür
    // olmadan sinyal gönderme. Aksi halde sunucu greeting'i Rive
    // yüklenmeden başlatır.
    if (!_isAvatarReadyForSession()) return;
    _avatarReadySentToServer = true;
    _sendEvent("avatar.ready", {"sessionId": _sessionId});
    _log("Signaled avatar.ready to server");
  }

  void _tryActivateCallUi() {
    if (!_connected || !_serverReportedReady || !_isAvatarReadyForSession()) {
      return;
    }
    if (!_avatarReadySentToServer) {
      _signalAvatarReadyToServer();
    }
    if (_sessionReady) return;
    setState(() {
      _sessionReady = true;
      _turnState = "listening";
      _status = _t("video_call_status_listening_active");
    });
    _maybeStopRingbackIfReady();
  }

  void _flushDeferredAgentAudio() {
    if (!_isAvatarReadyForSession()) return;
    final pending = List<String>.from(_deferredPlaybackUtterances);
    _deferredPlaybackUtterances.clear();
    for (final utteranceId in pending) {
      if (utteranceId.isEmpty || _completedTtsUtterances.contains(utteranceId)) {
        continue;
      }
      unawaited(_finalizeAndPlayTts(utteranceId, reason: "rive_ready_flush"));
    }
  }

  void _maybeStopRingbackIfReady() {
    final hasRiveAvatar =
        _activeAgent?.riveAvatar?.trim().isNotEmpty == true;
    final isAvatarReady = hasRiveAvatar ? _riveAvatarReady : true;
    if (_connected && _sessionReady && isAvatarReady) {
      if (_ringbackActive) _stopRingback();
      _startChatWhenReady();
    }
  }

  bool _chatStarted = false;
  void _startChatWhenReady() {
    if (_chatStarted) return;
    _chatStarted = true;
    _startOnboardingGateTimerIfNeeded();
    _startMicStreaming();
  }

  Future<void> _startRingback() async {
    try {
      await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringbackPlayer.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.speaker,
          focus: AudioContextConfigFocus.gain,
          respectSilence: false,
          stayAwake: true,
        ).build(),
      );
      await _ringbackPlayer.play(AssetSource("sounds/ringback.wav"));
      _ringbackActive = true;
      _log("Ringback started");
    } catch (e, st) {
      _log("Ringback start error: $e\n$st");
    }
  }

  Future<void> _stopRingback() async {
    if (!_ringbackActive) return;
    _ringbackActive = false;
    try {
      await _ringbackPlayer.stop();
    } catch (e) {
      _log("Ringback stop error: $e");
    }
  }

  void _log(String message) {
    if (!_debugLogs) return;
    debugPrint("[VideoCall] ${DateTime.now().toIso8601String()} | $message");
  }

  Future<void> _configureAudioPlayerSession() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.speaker,
          focus: AudioContextConfigFocus.gain,
          respectSilence: false,
          stayAwake: false,
        ).build(),
      );
      _log("Audio session configured (speaker, respectSilence=false)");
    } catch (e, st) {
      _log("Audio session configure error: $e\n$st");
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_isMicStreaming) {
      await _stopMicStreaming();
    } else {
      await _startMicStreaming();
    }
  }

  Future<void> _toggleCameraLens() async {
    if (_availableCameras.length < 2) {
      _log("Camera flip skipped: only ${_availableCameras.length} camera(s)");
      return;
    }
    final nextLens = _previewLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    try {
      await _switchCameraPreviewTo(nextLens);
      _log("Camera lens -> $nextLens");
    } catch (e, st) {
      _log("Camera flip error: $e\n$st");
    }
  }

  @override
  void initState() {
    super.initState();
    _log("VideocallView init");
    _audioPlayer.onPlayerComplete.listen((_) {
      _isAiSpeaking = false;
      _visemeNotifier.value = 0;
      _visemeTimeNotifier.value = 0;
      _sendPlaybackDone();
      if (mounted) {
        setState(() => _status = _t("video_call_status_listening_active"));
      }
      _log("Audio player complete -> AI speaking false");
    });
    _configureAudioPlayerSession();
    _startRingback();
    unawaited(_initCameraPreview());
    _connectVoiceWs();
    _setupOnboardingGateIfNeeded();
    // Dış güvenlik kemeri. İç katmanlar:
    //   - `_NetworkRiveAvatar` widget timeout: 45sn (photo fallback'a düşer ve
    //      `widget.onReady()` çağırır → buradaki `_onRiveAvatarReady`).
    //   - Backend greeting fallback: 75sn (`voiceChatServerV2.js`).
    // Bu timer Rive widget'ı hiç onReady çağırmazsa devreye giren son çare.
    // Önce 12sn idi → Rive yavaş yüklenirken Rive görünmeden avatar.ready
    // gönderiyor, server da greeting'i Rive yüklenmeden başlatıyordu.
    // 60sn → iç widget'ın 45sn'lik fallback'ine net bir tampon bırakır.
    _riveReadyFallbackTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted || _riveAvatarReady) return;
      _log("Rive outer fallback (60s) — forcing avatar.ready");
      _onRiveAvatarReady();
    });
  }

  Future<bool> _refreshOnboardingGateState() async {
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final isOnboarding = localService.isOnboardingFunnelActive();
    final isGatePending = localService.isOnboardingVideoGatePending();
    if (!isOnboarding || !isGatePending) {
      _shouldShowOnboardingGate = false;
      _onboardingSheetTimer?.cancel();
      return false;
    }
    _shouldShowOnboardingGate = true;
    return true;
  }

  Future<void> _setupOnboardingGateIfNeeded() async {
    await _refreshOnboardingGateState();
  }

  void _startOnboardingGateTimerIfNeeded() {
    _ensureOnboardingGateTimer();
  }

  Future<void> _ensureOnboardingGateTimer() async {
    final gateActive = await _refreshOnboardingGateState();
    if (!gateActive || _onboardingSheetShown) return;
    _onboardingSheetTimer?.cancel();
    _startOnboardingCountdown();
    _onboardingSheetTimer = Timer(
      const Duration(seconds: _onboardingGateDurationSeconds),
      () {
        _popWithOnboardingGateExpired();
      },
    );
  }

  Future<void> _popWithOnboardingGateExpired() async {
    if (!mounted || _onboardingSheetShown) return;
    _onboardingSheetShown = true;
    await _exitCallToChat(result: "onboarding_gate_expired");
  }

  Future<void> _exitCallToChat({Object? result}) async {
    if (_isExitingCall) return;
    _isExitingCall = true;
    _manualClose = true;
    _reconnectTimer?.cancel();
    _onboardingSheetTimer?.cancel();
    _onboardingCountdownTimer?.cancel();
    _playbackDoneTimer?.cancel();
    await _stopMicStreaming();
    await _audioPlayer.stop();
    await _stopPcmPlayback();
    await _wsSub?.cancel();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  String get _onboardingTimerText {
    final mm = (_onboardingCountdownSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_onboardingCountdownSeconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  void _startOnboardingCountdown() {
    _onboardingCountdownTimer?.cancel();
    _onboardingCountdownSeconds = _onboardingGateDurationSeconds;
    _onboardingCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) return;
      if (_onboardingCountdownSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _onboardingCountdownSeconds--;
      });
    });
  }

  Widget _buildOnboardingTopTimer() {
    if (!_shouldShowOnboardingGate || _onboardingSheetShown) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 12.h,
      left: 16.w,
      child: SafeArea(
        child:         Text(
                _onboardingTimerText,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Future<void> _showOnboardingPremiumSheet() async {
    if (!mounted || _onboardingSheetShown || !_shouldShowOnboardingGate) return;
    _onboardingSheetShown = true;
    _startOnboardingCountdown();
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          // margin: EdgeInsets.all(12.w),
          // padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
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

              Padding(
                padding: EdgeInsets.only(left: 15.r, right: 15.r),
                child: Text(
                  "${Translate.translate('video_gate_joined_prefix', context)} $_onboardingTimerText ${Translate.translate('video_gate_joined_suffix', context)}",
                  style: GoogleFonts.quicksand(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 7,
                        height: 7,
                        color: Color(0xffAB10E2),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate(
                        "video_gate_benefit_no_limits_title",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Translate.translate(
                        "video_gate_benefit_no_limits_suffix",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Color(0xff777777),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 7,
                        height: 7,
                        color: Color(0xffAB10E2),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate(
                        "video_gate_benefit_video_calls_title",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Translate.translate(
                        "video_gate_benefit_video_calls_suffix",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Color(0xff777777),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.only(left: 15.r),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 7,
                        height: 7,
                        color: Color(0xffAB10E2),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      Translate.translate(
                        "video_gate_benefit_deeper_title",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Translate.translate(
                        "video_gate_benefit_deeper_suffix",
                        context,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Color(0xff777777),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _onboardingTimerText,
                    style: GoogleFonts.quicksand(
                      color: Color(0xffF44336),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    Translate.translate(
                      "video_gate_waiting_counter_label",
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Color(0xff777777),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),
              MyGradientButton(
                margin: EdgeInsets.only(left: 15.r, right: 15.r),
                onTap: () async =>
                    _continueToLoginFromGate(action: "go_premium"),
                radius: BorderRadius.circular(30.r),
                size: Size(double.infinity, 50.h),
                child: Center(
                  child: Row(
                    children: [
                      HeroIcon(HeroIcons.sparkles,size: 16.w,color: Colors.white,style: HeroIconStyle.solid,),
                      SizedBox(width: 10.w),
                      Text(
                    Translate.translate(
                      "video_gate_answer_call_premium",
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                    ),
                  ),
                    ],
                  )
                ),
              ),
              SizedBox(height: 10.h),
              Center(
                child: TextButton(
                  onPressed: () async =>
                      _continueToLoginFromGate(action: "continue_normal"),
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _continueToLoginFromGate({required String action}) async {
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    await localService.setPostAuthAction(action);
    await localService.setOnboardingVideoGatePending(false);
    _onboardingSheetTimer?.cancel();
    _onboardingCountdownTimer?.cancel();
    _manualClose = true;
    _reconnectTimer?.cancel();
    await _stopMicStreaming();
    await _audioPlayer.stop();
    await _wsSub?.cancel();
    await _socket?.close();
    if (!mounted) return;

    const forceLogoutToLogin = true;
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
      arguments: {"forceLogoutToLogin": true},
    );
  }

  Future<void> _initCameraPreview() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        _log("No camera available for local preview");
        return;
      }
      await _switchCameraPreviewTo(_previewLensDirection);
    } catch (e, st) {
      _log("Camera init error: $e\n$st");
    }
  }

  Future<void> _switchCameraPreviewTo(CameraLensDirection lens) async {
    if (_availableCameras.isEmpty) return;
    final camera = _availableCameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => _availableCameras.first,
    );
    final old = _cameraController;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await old?.dispose();
    setState(() {
      _cameraController = controller;
      _previewLensDirection = camera.lensDirection;
      _isCameraPreviewReady = true;
    });
    _log("Camera preview ready (${camera.lensDirection})");
  }

  Widget _buildLocalCameraPreview() {
    final controller = _cameraController;
    if (controller == null ||
        !_isCameraPreviewReady ||
        !controller.value.isInitialized) {
      return Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white70, size: 28),
        ),
      );
    }
    return CameraPreview(controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizedTextsInitialized) return;
    _localizedTextsInitialized = true;
    _initLocalizedTexts();
  }

  String _buildWsUrl(String token) {
    final apiUri = Uri.parse(AppConstants.baseURL);
    final wsScheme = apiUri.scheme == "https" ? "wss" : "ws";
    final consultantId = _activeAgent?.id.toString();
    return apiUri
        .replace(
          scheme: wsScheme,
          path: "/realtime",
          queryParameters: {
            "token": token,
            if (consultantId != null) "consultantId": consultantId,
            "lang": "tr",
            "callMode": "video",
          },
        )
        .toString();
  }

  Future<void> _connectVoiceWs() async {
    final token = ref.read(AllControllers.userController)?.token ?? "";
    if (token.isEmpty) {
      _log("Token not found");
      setState(() => _status = _t("video_call_status_token_not_found"));
      return;
    }

    try {
      final wsUrl = _buildWsUrl(token);
      _log("Connecting WS -> $wsUrl");
      _socket = await WebSocket.connect(wsUrl);
      _log("WS connected successfully");
      _reconnectAttempts = 0;
      _sessionStartSent = false;
      _wsSub = _socket!.listen(
        _onWsMessage,
        onDone: _onWsClosed,
        onError: (Object err, StackTrace st) {
          _log("WS stream error: $err\n$st");
          _onWsClosed();
        },
      );
      if (!mounted) return;
      setState(() {
        _connected = true;
        _sessionReady = false;
        _serverReportedReady = false;
        _avatarReadySentToServer = false;
        _status = _t("video_call_status_connected_session_starting");
      });
      // Fallback: bazı backend sürümlerinde connection.ready event'i gelmeyebilir.
      _ensureSessionStarted("on_connect");
    } catch (e) {
      _log("WS connect failed: $e");
      if (!mounted) return;
      final wsUrl = _buildWsUrl(token);
      final shortUrl = Uri.parse(wsUrl).replace(queryParameters: {}).toString();
      setState(
        () => _status = _fmt("video_call_status_ws_connection_error", {
          "error": e.toString(),
          "endpoint": shortUrl,
        }),
      );
    }
  }

  void _onWsClosed() {
    _log("WS closed");
    _sessionStartSent = false;
    _chatStarted = false;
    unawaited(_stopMicStreaming());
    if (!mounted || _manualClose || _isExitingCall) return;
    if (_shouldShowOnboardingGate) {
      unawaited(_exitCallToChat(result: "onboarding_gate_expired"));
      return;
    }
    setState(() {
      _connected = false;
      _sessionReady = false;
      _serverReportedReady = false;
      _turnState = "idle";
      _status = _t("video_call_status_connection_closed");
    });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_shouldShowOnboardingGate || _manualClose || _isExitingCall) return;
    _reconnectTimer?.cancel();
    _onboardingSheetTimer?.cancel();
    _onboardingCountdownTimer?.cancel();
    const backoffMs = [500, 1000, 2000, 4000, 8000, 10000];
    final delayMs =
        backoffMs[_reconnectAttempts.clamp(0, backoffMs.length - 1)];
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(
      0,
      backoffMs.length - 1,
    );
    _log("Scheduling reconnect in ${delayMs}ms (attempt $_reconnectAttempts)");
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || _manualClose) return;
      setState(() => _status = _t("video_call_status_reconnecting"));
      _connectVoiceWs();
    });
  }

  void _sendEvent(String type, Map<String, dynamic> payload) {
    if (_socket == null) return;
    final event = {"type": type, "requestId": _nextReq(), "payload": payload};
    _sentEventCounter++;
    if (type != "audio.chunk" || _chunkLogCounter % 25 == 0) {
      _log("-> [$type] #$_sentEventCounter ${jsonEncode(event)}");
    }
    _socket!.add(jsonEncode(event));
  }

  void _startSession() {
    final conversationId = _activeConversationId;
    final agent = _activeAgent;
    _log(
      "Sending session.start (conversationId=$conversationId, botId=${agent?.id}, voiceId=${agent?.voiceId})",
    );
    _sendEvent("session.start", {
      "sessionId": _sessionId,
      if (conversationId != null) "conversationId": conversationId,
      if (agent != null) "botId": agent.id,
      if (agent?.voiceId != null) "voiceId": agent!.voiceId,
      "transport": "ws",
      "language": "tr-TR",
      "audio": {
        "codec": "pcm16le",
        "sampleRate": _sampleRate,
        "channels": _channels,
        "frameMs": _frameMs,
      },
    });
  }

  void _ensureSessionStarted(String source) {
    if (_sessionStartSent || !_connected || _sessionReady) return;
    if (!_isAvatarReadyForSession()) {
      _log("Delaying session.start until Rive ready (from $source)");
      return;
    }
    _sessionStartSent = true;
    _log("Ensuring session.start from $source");
    _startSession();
  }

  void _sendPlaybackDone() {
    if (_socket == null) return;
    _socket!.add(jsonEncode({"type": "playback_done"}));
    _log("-> playback_done");
  }

  void _schedulePlaybackDoneAfterMs(int durationMs) {
    _playbackDoneTimer?.cancel();
    final waitMs = durationMs.clamp(200, 120000);
    _playbackDoneTimer = Timer(Duration(milliseconds: waitMs), () {
      _playbackDoneTimer = null;
      _sendPlaybackDone();
      _isAiSpeaking = false;
      _visemeNotifier.value = 0;
      _visemeTimeNotifier.value = 0;
      if (mounted) {
        setState(() => _status = _t("video_call_status_listening_active"));
      }
    });
  }

  Future<void> _ensurePcmPlayer() async {
    if (_pcmPlayerReady) return;
    await FlutterPcmSound.setup(
      sampleRate: _ttsPcmSampleRate,
      channelCount: 1,
      iosAudioCategory: IosAudioCategory.playback,
    );
    _pcmPlayerReady = true;
  }

  Future<void> _playTtsAsPcm(List<int> bytes) async {
    await _ensurePcmPlayer();
    await _audioPlayer.stop();
    FlutterPcmSound.start();
    if (bytes.length >= 2) {
      final bd = ByteData.sublistView(Uint8List.fromList(bytes));
      final sampleCount = bytes.length ~/ 2;
      final samples = List<int>.generate(
        sampleCount,
        (i) => bd.getInt16(i * 2, Endian.little),
      );
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
    }
    final durationMs =
        ((bytes.length / (_ttsPcmSampleRate * 2)) * 1000).round() + 450;
    _schedulePlaybackDoneAfterMs(durationMs);
  }

  Future<void> _stopPcmPlayback() async {
    _playbackDoneTimer?.cancel();
    try {
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(const []));
    } catch (_) {}
  }

  Future<void> _playTtsAsMp3(List<int> bytes) async {
    await _stopPcmPlayback();
    await _audioPlayer.stop();
    await _audioPlayer.play(
      BytesSource(Uint8List.fromList(bytes), mimeType: "audio/mpeg"),
    );
  }

  Uint8List _pcm16ToWav(
    List<int> pcmBytes, {
    int sampleRate = _ttsPcmSampleRate,
    int channels = 1,
  }) {
    final pcm = Uint8List.fromList(pcmBytes);
    final dataSize = pcm.length;
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final header = ByteData(44);
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint32(12, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  Future<void> _playTtsAsWavFromPcm(List<int> bytes) async {
    await _stopPcmPlayback();
    await _audioPlayer.stop();
    await _audioPlayer.play(
      BytesSource(_pcm16ToWav(bytes), mimeType: "audio/wav"),
    );
    final durationMs =
        ((bytes.length / (_ttsPcmSampleRate * 2)) * 1000).round() + 450;
    _schedulePlaybackDoneAfterMs(durationMs);
  }

  void _bufferWsPcmBinary(dynamic raw) {
    final id = _activeTtsUtteranceId;
    if (id == null || id.isEmpty) return;
    final bytes = raw is Uint8List
        ? raw
        : Uint8List.fromList(raw is List<int> ? raw : <int>[]);
    if (bytes.isEmpty) return;

    // Rive avatar henüz görünür değilse audio'yu ertele — buffer'da biriksin,
    // Rive hazır olduğunda `_flushDeferredAgentAudio` finalize edip oynatır.
    if (!_isAvatarReadyForSession()) {
      _ttsBuffers.putIfAbsent(id, () => <int>[]).addAll(bytes);
      _deferredPlaybackUtterances.add(id);
      return;
    }

    // STREAMING: chunk'ı PCM player'a anında push et. Önceki davranış
    // bütün PCM'i `_ttsBuffers`'da topluyor, `tts.chunk{isLast:true}` gelene
    // kadar bekliyor, sonra topluca çalıyordu → ses tüm greeting süresince
    // (~2-3sn) sustu, sonra başlıyordu. Mindcoach pattern: her binary chunk
    // anında `FlutterPcmSound.feed` ile player kuyruğuna eklenir, ilk
    // chunk geldiğinde ses çıkar.
    _streamedUtteranceStart.putIfAbsent(id, () => DateTime.now());
    _streamedUtteranceBytes[id] = (_streamedUtteranceBytes[id] ?? 0) + bytes.length;
    // Bytes buffer'da tutulmaz — finalize fast path duration'ı
    // `_streamedUtteranceBytes`'tan hesaplıyor, replay yapmıyor.
    if (!_isAiSpeaking) {
      _isAiSpeaking = true;
      if (mounted) {
        setState(() => _status = _t("video_call_status_ai_speaking"));
      }
    }
    unawaited(_feedPcmChunkImmediate(bytes));
  }

  Future<void> _feedPcmChunkImmediate(Uint8List bytes) async {
    try {
      await _ensurePcmPlayer();
      FlutterPcmSound.start();
      if (bytes.length < 2) return;
      final bd = ByteData.sublistView(bytes);
      final sampleCount = bytes.length ~/ 2;
      final samples = List<int>.generate(
        sampleCount,
        (i) => bd.getInt16(i * 2, Endian.little),
      );
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
    } catch (e, st) {
      _log("PCM stream feed failed: $e\n$st");
    }
  }

  Future<void> _finalizeAndPlayTts(
    String utteranceId, {
    required String reason,
  }) async {
    if (utteranceId.isEmpty) return;
    if (_completedTtsUtterances.contains(utteranceId)) return;
    final bytes = _ttsBuffers.remove(utteranceId);
    if (utteranceId == _activeTtsUtteranceId) {
      _activeTtsUtteranceId = null;
    }

    // STREAMING fast path: chunk'lar zaten anında PCM player'a feed edildiyse
    // burada bytes'ları yeniden çalma. Yalnızca state finalize edip viseme'leri
    // streaming başlangıç anına göre schedule et + playback_done timer'ı kur.
    final streamedBytes = _streamedUtteranceBytes.remove(utteranceId);
    final streamStart = _streamedUtteranceStart.remove(utteranceId);
    if (streamedBytes != null && streamedBytes > 0) {
      _completedTtsUtterances.add(utteranceId);
      _lastTtsBytes = streamedBytes;
      _log(
        "TTS finalize (streamed): utterance=$utteranceId bytes=$streamedBytes reason=$reason",
      );
      _suppressVadUntilMs =
          DateTime.now().millisecondsSinceEpoch + _ttsFeedbackGuardMs;
      final visemes = _visemeBuffers[utteranceId] ?? const <_TtsFrame>[];
      final hasTimeline = _visemeTimelineLastFlags.containsKey(utteranceId);
      final audioStartAt = streamStart ?? DateTime.now();
      // Playback done timer toplam streaming süresine göre.
      final durationMs =
          ((streamedBytes / (_ttsPcmSampleRate * 2)) * 1000).round() + 450;
      _schedulePlaybackDoneAfterMs(durationMs);
      if (visemes.isNotEmpty) {
        _scheduleVisemesForUtterance(
          utteranceId: utteranceId,
          frames: visemes,
          audioStartAt: audioStartAt,
        );
      } else {
        _scheduleFallbackVisemesForUtterance(
          utteranceId: utteranceId,
          audioStartAt: audioStartAt,
          reason: hasTimeline
              ? "viseme.timeline.empty"
              : "viseme.timeline.missing",
        );
      }
      return;
    }

    // Streaming yolu kullanılmadıysa klasik buffer-then-play (deferred audio
    // veya streaming başarısızsa). Bytes boşsa finalize'i skip et.
    if (bytes == null || bytes.isEmpty) {
      _log(
        "TTS finalize skipped (empty buffer): utterance=$utteranceId reason=$reason",
      );
      return;
    }
    _completedTtsUtterances.add(utteranceId);
    _lastTtsBytes = bytes.length;
    _log(
      "TTS finalize/play: utterance=$utteranceId bytes=$_lastTtsBytes format=${_ttsUsesPcm ? "pcm" : "mp3"} reason=$reason",
    );
    _suppressVadUntilMs =
        DateTime.now().millisecondsSinceEpoch + _ttsFeedbackGuardMs;
    final visemes = _visemeBuffers[utteranceId] ?? const <_TtsFrame>[];
    final hasTimeline = _visemeTimelineLastFlags.containsKey(utteranceId);
    _isAiSpeaking = true;
    if (mounted) {
      setState(() => _status = _t("video_call_status_ai_speaking"));
    }
    try {
      final audioStartAt = DateTime.now();
      if (_ttsUsesPcm) {
        try {
          await _playTtsAsPcm(bytes);
        } catch (pcmErr, pcmSt) {
          _log("PCM playback failed, trying WAV fallback: $pcmErr\n$pcmSt");
          await _playTtsAsWavFromPcm(bytes);
        }
      } else {
        await _playTtsAsMp3(bytes);
      }
      if (visemes.isNotEmpty) {
        _scheduleVisemesForUtterance(
          utteranceId: utteranceId,
          frames: visemes,
          audioStartAt: audioStartAt,
        );
      } else {
        _scheduleFallbackVisemesForUtterance(
          utteranceId: utteranceId,
          audioStartAt: audioStartAt,
          reason: hasTimeline
              ? "viseme.timeline.empty"
              : "viseme.timeline.missing",
        );
      }
    } catch (e, st) {
      _log("TTS playback failed: $e\n$st");
      if (!_ttsUsesPcm) {
        try {
          final tempFile = File(
            "${Directory.systemTemp.path}/video_tts_${DateTime.now().millisecondsSinceEpoch}.mp3",
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          await _audioPlayer.stop();
          final audioStartAt = DateTime.now();
          await _audioPlayer.play(
            DeviceFileSource(tempFile.path, mimeType: "audio/mpeg"),
          );
          if (visemes.isNotEmpty) {
            _scheduleVisemesForUtterance(
              utteranceId: utteranceId,
              frames: visemes,
              audioStartAt: audioStartAt,
            );
          } else {
            _scheduleFallbackVisemesForUtterance(
              utteranceId: utteranceId,
              audioStartAt: audioStartAt,
              reason: hasTimeline
                  ? "viseme.timeline.empty"
                  : "viseme.timeline.missing",
            );
          }
          _log("Fallback device file play ok: ${tempFile.path}");
        } catch (e2, st2) {
          _log("Fallback device file play failed: $e2\n$st2");
          if (mounted) {
            setState(
              () => _status = _t("video_call_status_audio_playback_error"),
            );
          }
        }
      } else if (mounted) {
        setState(
          () => _status = _t("video_call_status_audio_playback_error"),
        );
      }
    }
    _ttsBuffers.remove(utteranceId);
    _visemeBuffers.remove(utteranceId);
    _visemeTimelineLastFlags.remove(utteranceId);
  }

  void _scheduleVisemesForUtterance({
    required String utteranceId,
    required List<_TtsFrame> frames,
    required DateTime audioStartAt,
  }) {
    _clearVisemeTimers(utteranceId);
    if (frames.isEmpty) {
      _log("No viseme frames for utterance=$utteranceId (fallback lip-sync)");
      return;
    }
    _visemeNotifier.value = 0;
    _visemeTimeNotifier.value = 0;

    final timers = <Timer>[];
    _visemeNotifier.value = 0;
    for (final frame in frames) {
      final ms = (frame.time * 1000).round();
      final timer = Timer(Duration(milliseconds: ms), () {
        _applyVisemeFrame(frame);
      });
      timers.add(timer);
    }
    final totalMs = (frames.last.time * 1000).round() + 120;
    timers.add(
      Timer(Duration(milliseconds: totalMs), () {
        _visemeNotifier.value = 0;
        _visemeTimeNotifier.value = 0;
      }),
    );
    _visemeTimers[utteranceId] = timers;
    _log(
      "Scheduled visemes: utterance=$utteranceId frames=${frames.length} start=${audioStartAt.toIso8601String()}",
    );
  }

  void _applyVisemeFrame(_TtsFrame frame) {
    _visemeNotifier.value = frame.id;
    _visemeTimeNotifier.value = frame.time;
  }

  void _scheduleFallbackVisemesForUtterance({
    required String utteranceId,
    required DateTime audioStartAt,
    required String reason,
  }) {
    _clearVisemeTimers(utteranceId);
    const pattern = <int>[0, 2, 8, 11, 8, 2];
    final timers = <Timer>[];
    for (var i = 0; i < 24; i++) {
      final frameId = pattern[i % pattern.length];
      timers.add(
        Timer(Duration(milliseconds: i * 90), () {
          _visemeNotifier.value = frameId;
          _visemeTimeNotifier.value = (i * 90) / 1000.0;
        }),
      );
    }
    timers.add(
      Timer(const Duration(milliseconds: 2200), () {
        _visemeNotifier.value = 0;
        _visemeTimeNotifier.value = 0;
      }),
    );
    _visemeTimers[utteranceId] = timers;
    _log(
      "Fallback visemes scheduled: utterance=$utteranceId reason=$reason start=${audioStartAt.toIso8601String()}",
    );
  }

  void _clearVisemeTimers(String utteranceId) {
    final timers = _visemeTimers.remove(utteranceId);
    if (timers == null) return;
    for (final t in timers) {
      t.cancel();
    }
  }

  void _clearAllVisemeTimers() {
    final keys = _visemeTimers.keys.toList(growable: false);
    for (final key in keys) {
      _clearVisemeTimers(key);
    }
  }

  void _stopAllVisemePlayback({String reason = "unknown"}) {
    _clearAllVisemeTimers();
    _visemeNotifier.value = 0;
    _visemeTimeNotifier.value = 0;
    _log("All viseme playback stopped (reason=$reason)");
  }

  void _onWsMessage(dynamic raw) {
    try {
      if (raw is Uint8List || raw is List<int>) {
        _bufferWsPcmBinary(raw);
        return;
      }
      final dynamic decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            _handleWsJson(Map<String, dynamic>.from(item));
          }
        }
        return;
      }
      if (decoded is! Map) return;
      _handleWsJson(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      _log("WS message parse/handle error: $e\n$st");
    }
  }

  void _handleWsJson(Map<String, dynamic> data) {
    final String rawType = (data["type"] ?? "").toString();
    final String type = rawType.startsWith("video.")
        ? rawType.substring("video.".length)
        : rawType;
    final payload = (data["payload"] is Map<String, dynamic>)
        ? data["payload"] as Map<String, dynamic>
        : <String, dynamic>{};
    _receivedEventCounter++;
    if (type != "tts.chunk" || _receivedEventCounter % 8 == 0) {
      _log("<- [$rawType] #$_receivedEventCounter ${jsonEncode(data)}");
    }

    switch (type) {
        case "connection.ready":
          setState(() => _status = _t("video_call_status_session_preparing"));
          _ensureSessionStarted("connection.ready");
          break;
        case "session.ready":
          _serverReportedReady = true;
          // ÖNEMLİ: Burada doğrudan `_signalAvatarReadyToServer()` çağırma.
          // O fonksiyon sadece `_connected && !_avatarReadySentToServer`
          // kontrolü yapıyor; Rive'ın gerçekten yüklenip yüklenmediğine
          // bakmıyor. Erken sinyal = sunucu greeting'i Rive görünmeden
          // başlatır → AI ağzı kıpırdamayan avatar üzerine konuşur.
          // Doğru kapı `_tryActivateCallUi`: `_isAvatarReadyForSession`
          // (yani `_riveAvatarReady`) sağlandıktan sonra sinyali yollar.
          // Rive yüklendiğinde `_onRiveAvatarReady` zaten ayrıca çağırır.
          _tryActivateCallUi();
          break;
        case "turn.state":
          final state = (payload["state"] ?? "").toString();
          _turnState = state;
          if (state == "listening") {
            _isAiSpeaking = false;
            setState(() => _status = _t("video_call_status_listening_you"));
          } else if (state == "thinking") {
            _isAiSpeaking = false;
            setState(() => _status = _t("video_call_status_ai_thinking"));
          } else if (state == "speaking") {
            _isAiSpeaking = true;
            setState(() => _status = _t("video_call_status_ai_speaking"));
          }
          break;
        case "stt.partial":
          setState(
            () =>
                _userText = _userLine((payload["transcript"] ?? "").toString()),
          );
          break;
        case "stt.final":
          setState(
            () =>
                _userText = _userLine((payload["transcript"] ?? "").toString()),
          );
          break;
        case "ai.response":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          final text = (payload["text"] ?? "").toString();
          setState(() => _aiText = _aiLine(text));
          _log("AI response received for utterance=$utteranceId");
          break;
        case "tts.start":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          final format = (payload["format"] ?? "").toString();
          unawaited(_stopRingback());
          if (utteranceId.isNotEmpty) {
            _activeTtsUtteranceId = utteranceId;
            _ttsUsesPcm = format.contains("pcm");
            _completedTtsUtterances.remove(utteranceId);
            _ttsBuffers[utteranceId] = <int>[];
            _visemeBuffers[utteranceId] = <_TtsFrame>[];
            _visemeTimelineLastFlags.remove(utteranceId);
            _clearVisemeTimers(utteranceId);
            _isAiSpeaking = true;
            setState(() => _status = _t("video_call_status_ai_speaking"));
          }
          break;
        case "tts.chunk":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          final b64 = (payload["audioBase64"] ?? "").toString();
          final isLast = payload["isLast"] == true;
          if (utteranceId.isNotEmpty) {
            _activeTtsUtteranceId = utteranceId;
          }
          if (utteranceId.isNotEmpty && b64.isNotEmpty) {
            _ttsBuffers.putIfAbsent(utteranceId, () => <int>[]);
            _ttsBuffers[utteranceId]!.addAll(base64Decode(b64));
            _log(
              "TTS chunk buffered: utterance=$utteranceId size=${_ttsBuffers[utteranceId]!.length} isLast=$isLast",
            );
          }
          if (utteranceId.isNotEmpty && isLast) {
            unawaited(
              _finalizeAndPlayTts(utteranceId, reason: "tts.chunk.isLast"),
            );
          }
          break;
        case "tts.end":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          _finalizeAndPlayTts(utteranceId, reason: "tts.end");
          break;
        case "viseme.timeline":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          final rawList = (payload["visemes"] as List?) ?? const [];
          if (utteranceId.isEmpty) {
            _log("Viseme timeline ignored: empty utteranceId");
            break;
          }
          final frames = rawList.map((e) {
            final m = (e as Map).cast<String, dynamic>();
            return _TtsFrame(
              time: (m["time"] as num?)?.toDouble() ?? 0,
              id: (m["id"] as num?)?.toInt() ?? 0,
            );
          }).toList()..sort((a, b) => a.time.compareTo(b.time));
          final isLast = payload["isLast"] == true;
          _visemeBuffers[utteranceId] = frames;
          _visemeTimelineLastFlags[utteranceId] = isLast;
          _log(
            "Viseme timeline received: utterance=$utteranceId frames=${frames.length} isLast=$isLast",
          );
          break;
        case "viseme.unavailable":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          final reason = (payload["reason"] ?? "unknown").toString();
          if (utteranceId.isNotEmpty) {
            _visemeBuffers[utteranceId] = const <_TtsFrame>[];
            _visemeTimelineLastFlags[utteranceId] = true;
          }
          _log("Viseme unavailable: utterance=$utteranceId reason=$reason");
          break;
        case "viseme.chunk":
          _log("Viseme chunk alindi: ${jsonEncode(payload)}");
          break;
        case "ai.interrupted":
          _playbackDoneTimer?.cancel();
          _audioPlayer.stop();
          unawaited(_stopPcmPlayback());
          _isAiSpeaking = false;
          _stopAllVisemePlayback(reason: "ai.interrupted");
          setState(() => _status = _t("video_call_status_ai_interrupted"));
          break;
        case "tts.stop":
          _playbackDoneTimer?.cancel();
          _audioPlayer.stop();
          unawaited(_stopPcmPlayback());
          _isAiSpeaking = false;
          _stopAllVisemePlayback(reason: "tts.stop");
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          if (utteranceId.isNotEmpty) {
            _clearVisemeTimers(utteranceId);
            _ttsBuffers.remove(utteranceId);
            _visemeBuffers.remove(utteranceId);
            _visemeTimelineLastFlags.remove(utteranceId);
          }
          setState(() => _status = _t("video_call_status_tts_stopped"));
          break;
        case "error":
          final message =
              (payload["message"] ?? _t("video_call_status_unknown_error"))
                  .toString();
          setState(
            () => _status = _fmt("video_call_status_error_prefix", {
              "message": message,
            }),
          );
          break;
        case "call_ended_idle":
          _log("Server ended call (idle / goodbye)");
          unawaited(
            _exitCallToChat(
              result: _shouldShowOnboardingGate
                  ? "onboarding_gate_expired"
                  : null,
            ),
          );
          break;
        case "connection_success":
          // ÖNEMLİ: Burada ringback'i durdurma. `connection_success` event'i
          // OpenAI session açılır açılmaz (Rive yüklenmeden ÇOK önce) gelir.
          // Erken durdurursak dıt-dıt sesi keser, Rive yüklenip greeting
          // başlayana kadar sessizlik kalır. Ringback `_maybeStopRingbackIfReady`
          // ile zaten doğru noktada (Rive ready + session ready) durur ya da
          // ilk gerçek konuşmada (`tts.start` / `ai_speaking_start`) kapanır.
          break;
        case "ai_speaking_start":
          unawaited(_stopRingback());
          break;
        case "ai_response_complete":
        case "playback_done":
        case "pong":
          break;
        default:
          break;
      }
  }

  void _sendPcmFrame(List<int> frame) {
    if (_currentUtteranceId == null) return;
    _sendEvent("audio.chunk", {
      "utteranceId": _currentUtteranceId,
      "chunkSeq": _chunkSeq++,
      "language": "tr-TR",
      "audio": {
        "codec": "pcm16le",
        "sampleRate": _sampleRate,
        "channels": _channels,
        "frameMs": _frameMs,
      },
      "audioBase64": base64Encode(frame),
    });
  }

  double _meanAbsPcm16(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < bytes.length; i += 2) {
      sum += data.getInt16(i, Endian.little).abs();
    }
    return sum / sampleCount;
  }

  void _startSpeechTurn() {
    _currentUtteranceId = "utt-${DateTime.now().millisecondsSinceEpoch}";
    _chunkSeq = 0;
    _isSpeechActive = true;
    _log("VAD start -> utterance=${_currentUtteranceId!}");
    _sendEvent("speech.start", {"utteranceId": _currentUtteranceId});
    if (_isAiSpeaking) {
      _log("Barge-in confirmed -> stopping local playback");
      _playbackDoneTimer?.cancel();
      _audioPlayer.stop();
      unawaited(_stopPcmPlayback());
      _isAiSpeaking = false;
      _stopAllVisemePlayback(reason: "barge-in.user-speech");
    }
  }

  void _stopSpeechTurn() {
    if (!_isSpeechActive || _currentUtteranceId == null) return;
    final utteranceId = _currentUtteranceId!;
    _log("VAD stop -> utterance=$utteranceId, chunkSeq=$_chunkSeq");
    _sendEvent("speech.stop", {"utteranceId": utteranceId});
    _sendEvent("utterance.end", {"utteranceId": utteranceId});
    _isSpeechActive = false;
    _currentUtteranceId = null;
    _chunkSeq = 0;
    _voicedFrames = 0;
    setState(() => _status = _t("video_call_status_waiting_ai_response"));
  }

  void _consumePcm(Uint8List bytes) {
    if (!_isMicStreaming) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final energy = _meanAbsPcm16(bytes);
    if (_isAiSpeaking && !_isSpeechActive && nowMs < _suppressVadUntilMs) {
      // TTS baslangicinda hoparlor geri-beslemesini speech olarak algilama.
      _voicedFrames = 0;
      return;
    }
    final elapsedMs = nowMs - _streamStartMs;
    final dynamicThreshold = math.max(
      _minVadThreshold,
      _noiseFloor * _noiseMultiplier,
    );
    final bool hardVoiced = energy >= _hardVoiceThreshold;
    final bool isVoiced = hardVoiced || energy >= dynamicThreshold;

    // Konusma olmadiginda noise floor'u guncelle; konusurken floor'u yukari tasima.
    if (!_isSpeechActive && !hardVoiced) {
      if (elapsedMs < 1500) {
        _noiseFloor = (_noiseFloor * 0.8) + (energy * 0.2);
      } else if (!isVoiced) {
        _noiseFloor = (_noiseFloor * 0.97) + (energy * 0.03);
      }
    }
    if (_chunkLogCounter % 25 == 0) {
      _log(
        "VAD frame: energy=${energy.toStringAsFixed(1)} noise=${_noiseFloor.toStringAsFixed(1)} threshold=${dynamicThreshold.toStringAsFixed(1)} hardVoiced=$hardVoiced voiced=$isVoiced active=$_isSpeechActive",
      );
    }

    if (isVoiced) {
      _voicedFrames += 1;
      _lastVoiceMs = nowMs;
      final requiredMs = _isAiSpeaking ? _bargeInMinStartMs : _speechMinStartMs;
      final strongBargeIn =
          !_isAiSpeaking ||
          energy >=
              math.max(
                _bargeInMinEnergy,
                dynamicThreshold * _bargeInEnergyMultiplier,
              );
      if (!_isSpeechActive &&
          (_voicedFrames * _frameMs) >= requiredMs &&
          strongBargeIn) {
        _startSpeechTurn();
      }
    } else if (!_isSpeechActive) {
      _voicedFrames = 0;
    }

    _pcmBuffer.addAll(bytes);
    while (_pcmBuffer.length >= _frameBytes) {
      final frame = _pcmBuffer.sublist(0, _frameBytes);
      _pcmBuffer.removeRange(0, _frameBytes);
      if (_isSpeechActive) {
        _chunkLogCounter++;
        _sendPcmFrame(frame);
      }
    }

    if (_isSpeechActive && (nowMs - _lastVoiceMs) >= _speechSilenceStopMs) {
      _stopSpeechTurn();
    }
  }

  Future<void> _startMicStreaming() async {
    if (!_connected || !_sessionReady) {
      _log(
        "Mic start blocked: connected=$_connected sessionReady=$_sessionReady",
      );
      setState(
        () => _status = _t("video_call_status_connection_session_not_ready"),
      );
      return;
    }
    if (_isMicStreaming) return;

    final hasPermission = await _recorder.hasPermission();
    _log("Mic permission: $hasPermission");
    if (!hasPermission) {
      setState(
        () => _status = _t("video_call_status_microphone_permission_required"),
      );
      return;
    }

    _pcmBuffer.clear();
    _chunkSeq = 0;
    _voicedFrames = 0;
    _lastVoiceMs = 0;
    _streamStartMs = DateTime.now().millisecondsSinceEpoch;
    _noiseFloor = 80.0;
    _isSpeechActive = false;
    _currentUtteranceId = null;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channels,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _log("Mic streaming started: ${_sampleRate}Hz/${_channels}ch");

    _recordSub?.cancel();
    _recordSub = stream.listen(
      _consumePcm,
      onError: (Object err, StackTrace st) {
        _log("Record stream error: $err\n$st");
        if (mounted)
          setState(() => _status = _t("video_call_status_record_stream_error"));
      },
    );

    if (!mounted) return;
    setState(() {
      _isMicStreaming = true;
      _status = _t("video_call_status_listening_active");
      _userText = _userLine("...");
    });
  }

  Future<void> _stopMicStreaming() async {
    if (!_isMicStreaming) return;
    _log("Stopping mic streaming");
    await _recordSub?.cancel();
    _recordSub = null;
    try {
      await _recorder.stop();
    } catch (e, st) {
      _log("Recorder stop error: $e\n$st");
    }

    if (_isSpeechActive) _stopSpeechTurn();
    _pcmBuffer.clear();

    if (!mounted) return;
    setState(() {
      _isMicStreaming = false;
      _status = _t("video_call_status_listening_off");
      _turnState = "idle";
    });
  }

  Future<void> _endCall() async {
    _log("Ending call");
    final gateActive = await _refreshOnboardingGateState();
    if (gateActive && !_onboardingSheetShown) {
      _log("Onboarding gate active -> returning to chat with gate result");
      await _exitCallToChat(result: "onboarding_gate_expired");
      return;
    }
    await _exitCallToChat();
  }

  @override
  void dispose() {
    _log("VideocallView dispose");
    _riveReadyFallbackTimer?.cancel();
    _manualClose = true;
    _reconnectTimer?.cancel();
    _playbackDoneTimer?.cancel();
    _onboardingSheetTimer?.cancel();
    _onboardingCountdownTimer?.cancel();
    _recordSub?.cancel();
    _recorder.dispose();
    _clearAllVisemeTimers();
    _visemeNotifier.dispose();
    _visemeTimeNotifier.dispose();
    _cameraController?.dispose();
    _ringbackActive = false;
    _audioPlayer.dispose();
    _ringbackPlayer.dispose();
    if (_pcmPlayerReady) {
      unawaited(FlutterPcmSound.release().catchError((Object _) {}));
    }
    _wsSub?.cancel();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(AllControllers.chatViewController).agent;
    final hasRiveAvatar = (agent?.riveAvatar?.trim().isNotEmpty ?? false);
    final isAvatarReady = hasRiveAvatar ? _riveAvatarReady : true;
    final showCallingScreen =
        !(_connected && _serverReportedReady && isAvatarReady && _sessionReady);
    final connectingLabel = !_connected
        ? _t("video_call_status_connecting")
        : (!isAvatarReady
            ? _t("video_call_status_loading_avatar")
            : _t("video_call_status_connected_session_starting"));

    return Scaffold(
      backgroundColor: Colors.transparent,

      body: Stack(
        children: [
          Image.asset(
            "assets/images/backgroud.jpeg",
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          /*
          Positioned(
            top: 44.h,
            left: 16.w,
            right: 16.w,
            child: Text(
              "$_status • ${_localizedTurnState(_turnState)}\n$_userText\n$_aiText",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ), */
          _buildAgentAvatar(agent),
          if (!showCallingScreen)
            Positioned(
              bottom: 106.h,
              right: 16.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: SizedBox(
                  width: 112,
                  height: 157,
                  child: _buildLocalCameraPreview(),
                ),
              ),
            ),
          if (!showCallingScreen) _buildOnboardingTopTimer(),
          if (showCallingScreen)
            Positioned.fill(
              child: BackgroundWidget(
                child: SizedBox.expand(
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 110.w,
                            height: 110.h,
                            child: _buildPhotoFallback(agent),
                          ),
                        ),
                        SizedBox(height: 18.h),
                        Text(
                          agent?.name ?? '',
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          connectingLabel,
                          style: GoogleFonts.quicksand(
                            color: Colors.white70,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 22.h),
                        SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => unawaited(_toggleCameraLens()),
                    child: Container(
                      width: 52.r,
                      height: 52.r,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          "assets/icons/vieo_call.svg",
                          width: 28.r,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 64.r,
                      height: 64.r,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          "assets/icons/end_call.svg",
                          width: 34.r,
                          fit: BoxFit.scaleDown,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
             GestureDetector(
                    onTap: _toggleMicrophone,
                    child: Container(
                      width: 52.r,
                      height: 52.r,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                         _isMicStreaming ? "assets/icons/mic.svg" : "assets/icons/mic-slash.svg",
                          width: 28.r,
                        ),
                      ),
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
}

class _TtsFrame {
  final double time;
  final int id;
  const _TtsFrame({required this.time, required this.id});
}

class _NetworkRiveAvatar extends StatefulWidget {
  const _NetworkRiveAvatar({
    required this.url,
    required this.fallback,
    required this.visemeNotifier,
    required this.visemeTimeNotifier,
    required this.onReady,
  });

  final String url;
  final Widget fallback;
  final ValueNotifier<int> visemeNotifier;
  final ValueNotifier<double> visemeTimeNotifier;
  final VoidCallback onReady;

  @override
  State<_NetworkRiveAvatar> createState() => _NetworkRiveAvatarState();
}

class _NetworkRiveAvatarState extends State<_NetworkRiveAvatar> {
  FileLoader? _loader;
  Object? _lastRiveError;
  RiveWidgetController? _riveController;
  ViewModelInstance? _viewModel;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _createLoader();
    widget.visemeNotifier.addListener(_onVisemeChanged);
    widget.visemeTimeNotifier.addListener(_onVisemeChanged);
  }

  @override
  void didUpdateWidget(covariant _NetworkRiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visemeNotifier != widget.visemeNotifier) {
      oldWidget.visemeNotifier.removeListener(_onVisemeChanged);
      widget.visemeNotifier.addListener(_onVisemeChanged);
    }
    if (oldWidget.visemeTimeNotifier != widget.visemeTimeNotifier) {
      oldWidget.visemeTimeNotifier.removeListener(_onVisemeChanged);
      widget.visemeTimeNotifier.addListener(_onVisemeChanged);
    }
    if (oldWidget.url != widget.url) {
      _disposeLoader();
      _createLoader();
      _readyNotified = false;
    }
  }

  void _notifyReadyOnce() {
    if (_readyNotified) return;
    _readyNotified = true;
    widget.onReady();
  }

  void _onVisemeChanged() {
    _applyViseme(widget.visemeNotifier.value);
  }

  void _createLoader() {
    _lastRiveError = null;
    _viewModel = null;
    _riveController = null;
    _loader = FileLoader.fromUrl(widget.url, riveFactory: Factory.rive);
  }

  void _disposeLoader() {
    _loader?.dispose();
    _loader = null;
  }

  @override
  void dispose() {
    widget.visemeNotifier.removeListener(_onVisemeChanged);
    widget.visemeTimeNotifier.removeListener(_onVisemeChanged);
    _disposeLoader();
    super.dispose();
  }

  void _ensureDataBinding(RiveWidgetController controller) {
    if (identical(_riveController, controller) && _viewModel != null) return;
    _riveController = controller;
    try {
      _viewModel = controller.dataBind(DataBind.auto());
      _updateRiveProperty("duration", 65.0);
      _updateRiveProperty("visemeNum", 0.0);
      _updateRiveProperty("talk", false);
    } catch (e) {
      debugPrint("[VideoCall] Rive databind error: $e");
      _viewModel = null;
    }
  }

  void _updateRiveProperty(String name, dynamic value) {
    final vm = _viewModel;
    if (vm == null) return;
    try {
      if (name == "talk" && value is bool) {
        vm.boolean(name)?.value = value;
      } else if ((name == "visemeNum" ||
              name == "duration" ||
              name == "visemdurationeNum") &&
          (value is double || value is int)) {
        vm.number(name)?.value = value.toDouble();
      }
    } catch (_) {
      try {
        for (final prop in vm.properties) {
          if (prop.name == name) {
            (prop as dynamic).value = value;
            return;
          }
        }
      } catch (e2) {
        debugPrint("[VideoCall] Rive property update error ($name): $e2");
      }
    }
  }

  void _applyViseme(int id) {
    if (_viewModel == null) return;
    _updateRiveProperty("visemeNum", id.toDouble());
    _updateRiveProperty("visemdurationeNum", widget.visemeTimeNotifier.value);
    _updateRiveProperty("talk", true);
    Future.delayed(const Duration(milliseconds: 45), () {
      if (!mounted) return;
      _updateRiveProperty("talk", false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loader = _loader;
    if (loader == null) return widget.fallback;
    return RiveWidgetBuilder(
      fileLoader: loader,
      builder: (context, state) => switch (state) {
        RiveLoading() => const Center(child: CircularProgressIndicator()),
        RiveFailed() => _buildRiveFailed(state.error),
        RiveLoaded() => Builder(
          builder: (context) {
            _ensureDataBinding(state.controller);
            _notifyReadyOnce();
            return RiveWidget(controller: state.controller, fit: Fit.cover);
          },
        ),
      },
    );
  }

  Widget _buildRiveFailed(Object error) {
    if (_lastRiveError != error) {
      _lastRiveError = error;
      debugPrint("[VideoCall] Rive render failed for ${widget.url}: $error");
    }
    _notifyReadyOnce();
    return widget.fallback;
  }
}
