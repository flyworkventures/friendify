import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:rive/rive.dart' hide File;

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
  static const int _speechMinStartMs = 60;
  static const int _speechSilenceStopMs = 900;
  static const double _minVadThreshold = 120.0;
  static const double _hardVoiceThreshold = 700.0;
  static const double _noiseMultiplier = 2.2;
  static const int _bargeInMinStartMs = 260;
  static const double _bargeInEnergyMultiplier = 1.8;
  static const double _bargeInMinEnergy = 1200.0;
  static const int _ttsFeedbackGuardMs = 280;
  static const bool _debugLogs = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
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

  bool _connected = false;
  bool _sessionReady = false;
  bool _isMicStreaming = false;
  bool _isSpeakerOn = true;
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
  CameraController? _frontCameraController;
  bool _isFrontCameraReady = false;

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
        ? Image.network(
            agent!.photoURL,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
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
    setState(() => _riveAvatarReady = true);
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

  Future<void> _toggleSpeaker() async {
    try {
      _isSpeakerOn = !_isSpeakerOn;
      await _audioPlayer.setAudioContext(
        AudioContextConfig(
          route: _isSpeakerOn
              ? AudioContextConfigRoute.speaker
              : AudioContextConfigRoute.earpiece,
          focus: AudioContextConfigFocus.gain,
          respectSilence: false,
          stayAwake: false,
        ).build(),
      );
      if (!mounted) return;
      setState(() {});
      _log("Speaker toggled -> ${_isSpeakerOn ? "on" : "off"}");
    } catch (e, st) {
      _log("Speaker toggle error: $e\n$st");
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
      if (mounted) {
        setState(() => _status = _t("video_call_status_listening_active"));
      }
      _log("Audio player complete -> AI speaking false");
    });
    _configureAudioPlayerSession();
    _initFrontCameraPreview();
    _connectVoiceWs();
  }

  Future<void> _initFrontCameraPreview() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _log("No camera available for local preview");
        return;
      }
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _frontCameraController?.dispose();
      setState(() {
        _frontCameraController = controller;
        _isFrontCameraReady = true;
      });
      _log("Front camera preview initialized");
    } catch (e, st) {
      _log("Front camera init error: $e\n$st");
    }
  }

  Widget _buildLocalCameraPreview() {
    final controller = _frontCameraController;
    if (controller == null || !_isFrontCameraReady || !controller.value.isInitialized) {
      return Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white70, size: 28),
        ),
      );
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(math.pi),
      child: CameraPreview(controller),
    );
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
    return apiUri
        .replace(
          scheme: wsScheme,
          path: "/ws/voice",
          queryParameters: {"token": token},
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
    _stopMicStreaming();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _sessionReady = false;
      _turnState = "idle";
      _status = _t("video_call_status_connection_closed");
    });
    if (_manualClose) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
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
    _sessionStartSent = true;
    _log("Ensuring session.start from $source");
    _startSession();
  }

  Future<void> _finalizeAndPlayTts(
    String utteranceId, {
    required String reason,
  }) async {
    if (utteranceId.isEmpty) return;
    if (_completedTtsUtterances.contains(utteranceId)) return;
    final bytes = _ttsBuffers.remove(utteranceId);
    if (bytes == null || bytes.isEmpty) {
      _log(
        "TTS finalize skipped (empty buffer): utterance=$utteranceId reason=$reason",
      );
      return;
    }
    _completedTtsUtterances.add(utteranceId);
    _lastTtsBytes = bytes.length;
    _log(
      "TTS finalize/play: utterance=$utteranceId bytes=$_lastTtsBytes reason=$reason enough=${_lastTtsBytes > 10240}",
    );
    _suppressVadUntilMs =
        DateTime.now().millisecondsSinceEpoch + _ttsFeedbackGuardMs;
    final visemes = _visemeBuffers[utteranceId] ?? const <_TtsFrame>[];
    final hasTimeline = _visemeTimelineLastFlags.containsKey(utteranceId);
    try {
      await _audioPlayer.stop();
      final audioStartAt = DateTime.now();
      await _audioPlayer.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: "audio/mpeg"),
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
    } catch (e, st) {
      _log("BytesSource play failed, trying device file fallback: $e\n$st");
      try {
        final tempFile = File(
          "${Directory.systemTemp.path}/voice_tts_${DateTime.now().millisecondsSinceEpoch}.mp3",
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
    }
    _isAiSpeaking = true;
    if (mounted) {
      setState(() => _status = _t("video_call_status_ai_speaking"));
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
      final Map<String, dynamic> data = jsonDecode(raw.toString());
      final String rawType = (data["type"] ?? "").toString();
      final String type = rawType.startsWith("video.")
          ? rawType.substring("video.".length)
          : rawType;
      final payload = (data["payload"] is Map<String, dynamic>)
          ? data["payload"] as Map<String, dynamic>
          : <String, dynamic>{};
      _receivedEventCounter++;
      _log("<- [$rawType] #$_receivedEventCounter ${jsonEncode(data)}");

      switch (type) {
        case "connection.ready":
          setState(() => _status = _t("video_call_status_session_preparing"));
          _ensureSessionStarted("connection.ready");
          break;
        case "session.ready":
          setState(() {
            _sessionReady = true;
            _turnState = "listening";
            _status = _t("video_call_status_listening_active");
          });
          _startMicStreaming();
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
          if (utteranceId.isNotEmpty) {
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
          if (utteranceId.isNotEmpty && b64.isNotEmpty) {
            _ttsBuffers.putIfAbsent(utteranceId, () => <int>[]);
            _ttsBuffers[utteranceId]!.addAll(base64Decode(b64));
            _log(
              "TTS chunk buffered: utterance=$utteranceId size=${_ttsBuffers[utteranceId]!.length} isLast=$isLast",
            );
          } else if (utteranceId.isNotEmpty) {
            _log(
              "TTS chunk received without audioBase64: utterance=$utteranceId isLast=$isLast",
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
          _audioPlayer.stop();
          _isAiSpeaking = false;
          _stopAllVisemePlayback(reason: "ai.interrupted");
          setState(() => _status = _t("video_call_status_ai_interrupted"));
          break;
        case "tts.stop":
          _audioPlayer.stop();
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
        default:
          break;
      }
    } catch (e, st) {
      _log("WS message parse/handle error: $e\n$st");
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
      _audioPlayer.stop();
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
    _manualClose = true;
    _reconnectTimer?.cancel();
    await _stopMicStreaming();
    await _audioPlayer.stop();
    await _wsSub?.cancel();
    await _socket?.close();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _log("VideocallView dispose");
    _manualClose = true;
    _reconnectTimer?.cancel();
    _recordSub?.cancel();
    _recorder.dispose();
    _clearAllVisemeTimers();
    _visemeNotifier.dispose();
    _visemeTimeNotifier.dispose();
    _frontCameraController?.dispose();
    _audioPlayer.dispose();
    _wsSub?.cancel();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(AllControllers.chatViewController).agent;
    final hasRiveAvatar = (agent?.riveAvatar?.trim().isNotEmpty ?? false);
    final isAvatarReady = hasRiveAvatar ? _riveAvatarReady : true;
    final showCallingScreen = !(_connected && _sessionReady && isAvatarReady);

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
              top: 96.h,
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
          if (showCallingScreen)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
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
                        _t("video_call_status_connecting"),
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

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleMicrophone,
                    child: Container(
                      width: 52.w,
                      height: 52.h,
                      decoration: BoxDecoration(
                        color: _isMicStreaming
                            ? Colors.black.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          "assets/icons/mic.svg",
                          width: 28.w,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 64.w,
                      height: 64.h,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          "assets/icons/call-slash.svg",
                          width: 34.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),

                  GestureDetector(
                    onTap: _toggleSpeaker,
                    child: Container(
                      width: 52.w,
                      height: 52.h,
                      decoration: BoxDecoration(
                        color: _isSpeakerOn
                            ? Colors.black.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          "assets/icons/hoporlor.svg",
                          width: 28.w,
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
      _updateRiveProperty("duration", 200.0);
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
