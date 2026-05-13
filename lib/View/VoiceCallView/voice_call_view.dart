import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:record/record.dart';

class VoiceCallView extends ConsumerStatefulWidget {
  const VoiceCallView({super.key});

  @override
  ConsumerState<VoiceCallView> createState() => _VoiceCallViewState();
}

class _VoiceCallViewState extends ConsumerState<VoiceCallView>
    with TickerProviderStateMixin {
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
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _pcmBuffer = [];
  final Map<String, List<int>> _ttsBuffers = {};

  WebSocket? _socket;
  StreamSubscription? _wsSub;
  StreamSubscription<Uint8List>? _recordSub;
  StreamSubscription<int>? _proximitySub;
  Timer? _reconnectTimer;
  Timer? _ringbackTimer;
  bool _ringbackActive = false;
  bool _proximityScreenOffEnabled = false;
  bool _isProximityNear = false;

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

  late AnimationController _pulseCtrl;

  Color _stateColor() {
    switch (_turnState) {
      case "listening":
        return const Color(0xFF5ED085);
      case "thinking":
        return const Color(0xFFF5A623);
      case "speaking":
        return const Color(0xFF4A7BFF);
      default:
        return const Color(0xFFAB10E2);
    }
  }

  String _stateText() {
    switch (_turnState) {
      case "listening":
        return "Seni dinliyorum";
      case "thinking":
        return "Düşünüyorum...";
      case "speaking":
        return "Konuşuyorum";
      default:
        return "";
    }
  }

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

  String _userLine(String text) => "${_t("voice_call_user_prefix")}: $text";
  String _aiLine(String text) => "${_t("voice_call_ai_prefix")}: $text";
  String _localizedTurnState(String state) {
    switch (state) {
      case "listening":
        return _t("voice_call_turn_listening");
      case "thinking":
        return _t("voice_call_turn_thinking");
      case "speaking":
        return _t("voice_call_turn_speaking");
      default:
        return _t("voice_call_turn_idle");
    }
  }

  void _initLocalizedTexts() {
    _status = _t("voice_call_status_connecting");
    _userText = _userLine("...");
    _aiText = _aiLine("...");
  }

  Widget _buildPhotoFallback(AgentModel? agent) {
    return agent?.photoURL.isNotEmpty == true
        ? Image.network(
            agent!.photoURL,
            fit: BoxFit.cover,
            alignment: Alignment(0, -1),
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

  void _log(String message) {
    if (!_debugLogs) return;
    debugPrint("[VoiceCall] ${DateTime.now().toIso8601String()} | $message");
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
      final route = _isSpeakerOn
          ? AudioContextConfigRoute.speaker
          : AudioContextConfigRoute.earpiece;
      await _audioPlayer.setAudioContext(
        AudioContextConfig(
          route: route,
          focus: AudioContextConfigFocus.gain,
          respectSilence: false,
          stayAwake: false,
        ).build(),
      );
      try {
        await _ringbackPlayer.setAudioContext(
          AudioContextConfig(
            route: route,
            focus: AudioContextConfigFocus.gain,
            respectSilence: false,
            stayAwake: false,
          ).build(),
        );
      } catch (_) {}
      _applyProximityScreenOff();
      if (!mounted) return;
      setState(() {});
      _log("Speaker toggled -> ${_isSpeakerOn ? "on" : "off"}");
    } catch (e, st) {
      _log("Speaker toggle error: $e\n$st");
    }
  }

  Future<void> _startRingback() async {
    try {
      await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringbackPlayer.setAudioContext(
        AudioContextConfig(
          route: _isSpeakerOn
              ? AudioContextConfigRoute.speaker
              : AudioContextConfigRoute.earpiece,
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

  Future<void> _initProximitySensor() async {
    try {
      _proximitySub = ProximitySensor.events.listen((int event) {
        final near = event > 0;
        if (_isProximityNear == near) return;
        _isProximityNear = near;
        _log("Proximity changed -> ${near ? "near" : "far"}");
      });
      _applyProximityScreenOff();
    } catch (e, st) {
      _log("Proximity sensor init error: $e\n$st");
    }
  }

  void _applyProximityScreenOff() {
    final shouldEnable = !_isSpeakerOn;
    if (shouldEnable == _proximityScreenOffEnabled) return;
    _proximityScreenOffEnabled = shouldEnable;
    unawaited(
      Future(
        () => ProximitySensor.setProximityScreenOff(shouldEnable),
      ).catchError((Object _) {}),
    );
    _log("Proximity screen-off -> $shouldEnable");
  }

  Future<void> _playRingbackThenConnect() async {
    await _startRingback();
    _ringbackTimer?.cancel();
    _ringbackTimer = Timer(const Duration(seconds: 3), () async {
      await _stopRingback();
      if (!mounted) return;
      await _connectVoiceWs();
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _log("VoiceCallView init");
    _audioPlayer.onPlayerComplete.listen((_) {
      _isAiSpeaking = false;
      if (mounted) {
        setState(() => _status = _t("voice_call_status_listening_active"));
      }
      _log("Audio player complete -> AI speaking false");
    });
    _configureAudioPlayerSession();
    _initProximitySensor();
    _playRingbackThenConnect();
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
      setState(() => _status = _t("voice_call_status_token_not_found"));
      return;
    }

    try {
      final wsUrl = _buildWsUrl(token);
      _log("Connecting WS -> $wsUrl");
      _socket = await WebSocket.connect(wsUrl);
      _log("WS connected successfully");
      _reconnectAttempts = 0;
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
        _status = _t("voice_call_status_connected_session_starting");
      });
    } catch (e) {
      _log("WS connect failed: $e");
      if (!mounted) return;
      final wsUrl = _buildWsUrl(token);
      final shortUrl = Uri.parse(wsUrl).replace(queryParameters: {}).toString();
      setState(
        () => _status = _fmt("voice_call_status_ws_connection_error", {
          "error": e.toString(),
          "endpoint": shortUrl,
        }),
      );
    }
  }

  void _onWsClosed() {
    _log("WS closed");
    _stopMicStreaming();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _sessionReady = false;
      _turnState = "idle";
      _status = _t("voice_call_status_connection_closed");
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
      setState(() => _status = _t("voice_call_status_reconnecting"));
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
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: "audio/mpeg"),
      );
    } catch (e, st) {
      _log("BytesSource play failed, trying device file fallback: $e\n$st");
      try {
        final tempFile = File(
          "${Directory.systemTemp.path}/voice_tts_${DateTime.now().millisecondsSinceEpoch}.mp3",
        );
        await tempFile.writeAsBytes(bytes, flush: true);
        await _audioPlayer.stop();
        await _audioPlayer.play(
          DeviceFileSource(tempFile.path, mimeType: "audio/mpeg"),
        );
        _log("Fallback device file play ok: ${tempFile.path}");
      } catch (e2, st2) {
        _log("Fallback device file play failed: $e2\n$st2");
        if (mounted) {
          setState(
            () => _status = _t("voice_call_status_audio_playback_error"),
          );
        }
      }
    }
    _isAiSpeaking = true;
    if (mounted) {
      setState(() => _status = _t("voice_call_status_ai_speaking"));
    }
  }

  void _onWsMessage(dynamic raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw.toString());
      final String type = (data["type"] ?? "").toString();
      final payload = (data["payload"] is Map<String, dynamic>)
          ? data["payload"] as Map<String, dynamic>
          : <String, dynamic>{};
      _receivedEventCounter++;
      _log("<- [$type] #$_receivedEventCounter ${jsonEncode(data)}");

      switch (type) {
        case "connection.ready":
          setState(() => _status = _t("voice_call_status_session_preparing"));
          _startSession();
          break;
        case "session.ready":
          _stopRingback();
          setState(() {
            _sessionReady = true;
            _turnState = "listening";
            _status = _t("voice_call_status_listening_active");
          });
          _startMicStreaming();
          break;
        case "turn.state":
          final state = (payload["state"] ?? "").toString();
          _turnState = state;
          if (state == "listening") {
            _isAiSpeaking = false;
            setState(() => _status = _t("voice_call_status_listening_you"));
          } else if (state == "thinking") {
            _isAiSpeaking = false;
            setState(() => _status = _t("voice_call_status_ai_thinking"));
          } else if (state == "speaking") {
            _isAiSpeaking = true;
            setState(() => _status = _t("voice_call_status_ai_speaking"));
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
            _isAiSpeaking = true;
            setState(() => _status = _t("voice_call_status_ai_speaking"));
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
          if (utteranceId.isNotEmpty && isLast) {
            _finalizeAndPlayTts(utteranceId, reason: "tts.chunk.isLast");
          }
          break;
        case "tts.end":
          final utteranceId = (payload["utteranceId"] ?? "").toString();
          _finalizeAndPlayTts(utteranceId, reason: "tts.end");
          break;
        case "ai.interrupted":
          _audioPlayer.stop();
          _isAiSpeaking = false;
          setState(() => _status = _t("voice_call_status_ai_interrupted"));
          break;
        case "tts.stop":
          _audioPlayer.stop();
          _isAiSpeaking = false;
          setState(() => _status = _t("voice_call_status_tts_stopped"));
          break;
        case "error":
          final message =
              (payload["message"] ?? _t("voice_call_status_unknown_error"))
                  .toString();
          setState(
            () => _status = _fmt("voice_call_status_error_prefix", {
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
    setState(() => _status = _t("voice_call_status_waiting_ai_response"));
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
        () => _status = _t("voice_call_status_connection_session_not_ready"),
      );
      return;
    }
    if (_isMicStreaming) return;

    final hasPermission = await _recorder.hasPermission();
    _log("Mic permission: $hasPermission");
    if (!hasPermission) {
      setState(
        () => _status = _t("voice_call_status_microphone_permission_required"),
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
          setState(() => _status = _t("voice_call_status_record_stream_error"));
      },
    );

    if (!mounted) return;
    setState(() {
      _isMicStreaming = true;
      _status = _t("voice_call_status_listening_active");
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
      _status = _t("voice_call_status_listening_off");
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
    _pulseCtrl.dispose();
    _log("VoiceCallView dispose");
    _manualClose = true;
    _reconnectTimer?.cancel();
    _ringbackTimer?.cancel();
    _ringbackActive = false;
    _proximitySub?.cancel();
    if (_proximityScreenOffEnabled) {
      _proximityScreenOffEnabled = false;
      unawaited(
        Future(
          () => ProximitySensor.setProximityScreenOff(false),
        ).catchError((Object _) {}),
      );
    }
    _recordSub?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _ringbackPlayer.dispose();
    _wsSub?.cancel();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(AllControllers.chatViewController).agent;
    final showCallingScreen = !(_connected && _sessionReady);
    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,

        body: SafeArea(
          child: Stack(
            children: [
              /*
              Positioned(
                top: 20.h,
                left: 20.w,
                right: 20.w,
                child: Text(
                  "$_status • ${_localizedTurnState(_turnState)}\n$_userText\n$_aiText",
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11.sp,
                  ),
                ),
              ),
*/
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, _) {
                        final double t = Curves.easeInOut.transform(
                          _pulseCtrl.value,
                        );
                        final Color color = _stateColor();
                        return SizedBox(
                          width: 280.w,
                          height: 280.w,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 280.w,
                                height: 280.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withOpacity(0.08 + 0.10 * t),
                                ),
                              ),
                              Container(
                                width: 250.w,
                                height: 250.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withOpacity(0.16 + 0.12 * t),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                width: 200.w,
                                height: 200.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.35),
                                      blurRadius: 24 + 8 * t,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildPhotoFallback(agent),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      agent?.name ?? _t("voice_call_title_fallback"),
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24.sp,
                      ),
                    ),
                    if (_turnState != "idle") ...[
                      SizedBox(height: 12.h),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _stateText(),
                          key: ValueKey(_turnState),
                          style: GoogleFonts.quicksand(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

             Padding(padding: EdgeInsets.only(bottom: 40.h),

              child:  Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _toggleMicrophone,
                      child: Container(
                        width: 82.w,
                        height: 55.h,
                        decoration: BoxDecoration(
                          color: _isMicStreaming
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                          _isMicStreaming ? "assets/icons/mic.svg" : "assets/icons/mic-slash.svg",
                            width: 34.w,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 82.w,
                        height: 55.h,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.5),
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
                        width: 82.w,
                        height: 55.h,
                        decoration: BoxDecoration(
                          color: _isSpeakerOn
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: SvgPicture.asset(_isSpeakerOn ? "assets/icons/hoporlor.svg" : "assets/icons/volume-slash.svg"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
             ),
              if (showCallingScreen)
                Positioned.fill(
                  child: BackgroundWidget(
                    child: SizedBox.expand(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (context, _) {
                              final double t = Curves.easeInOut.transform(
                                _pulseCtrl.value,
                              );
                              const Color color = Color(0xFF9AA0A6);
                              return SizedBox(
                                width: 180.w,
                                height: 180.w,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 180.w,
                                      height: 180.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color.withOpacity(0.08 + 0.10 * t),
                                      ),
                                    ),
                                    Container(
                                      width: 155.w,
                                      height: 155.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color.withOpacity(0.16 + 0.12 * t),
                                      ),
                                    ),
                                    Container(
                                      width: 120.w,
                                      height: 120.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: color, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.35),
                                            blurRadius: 18 + 6 * t,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _buildPhotoFallback(agent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 18.h),
                          Text(
                            agent?.name ?? _t("voice_call_title_fallback"),
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _t("voice_call_status_connecting"),
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
            ],
          ),
        ),
      ),
    );
  }
}
