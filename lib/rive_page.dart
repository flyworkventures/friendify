import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AvatarDataBindingPage(),
    ),
  );
}

class AvatarDataBindingPage extends StatefulWidget {
  const AvatarDataBindingPage({super.key});

  @override
  State<AvatarDataBindingPage> createState() => _AvatarDataBindingPageState();
}

class _AvatarDataBindingPageState extends State<AvatarDataBindingPage> {
  late final FileLoader _fileLoader;
  RiveWidgetController? _controller;
  ViewModelInstance? _viewModel;

  final TextEditingController _textController = TextEditingController(
    text:
        "",
  );

  List<Map<String, dynamic>> visemes = [
    {"id": 0, "time": 0},
    {"id": 8, "time": 0.15},
    {"id": 1, "time": 0.33},
    {"id": 18, "time": 0.43},
    {"id": 2, "time": 0.47},
    {"id": 8, "time": 0.55},
    {"id": 18, "time": 0.61},
    {"id": 2, "time": 0.67},
    {"id": 20, "time": 0.75},
    {"id": 1, "time": 0.85},
    {"id": 18, "time": 0.92},
    {"id": 11, "time": 0.99},
    {"id": 8, "time": 1.55},
    {"id": 18, "time": 1.76},
    {"id": 2, "time": 1.83},
    {"id": 2, "time": 1.91},
    {"id": 8, "time": 2.1},
    {"id": 18, "time": 2.24},
    {"id": 8, "time": 2.45},
    {"id": 11, "time": 2.59},
    {"id": 8, "time": 2.66},
    {"id": 0, "time": 3.22},
  ];

  bool _isTalking = false;
  Timer? _talkTimer;
  List<Timer> _visemeTimers = []; // Viseme timer'larını takip etmek için

  // TEST: tek tek / loop
  int _selectedViseme = 0;
  bool _isVisemeLooping = false;
  Timer? _visemeLoopTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
    _fileLoader = FileLoader.fromAsset(
      "assets/female_char_3.riv",
      riveFactory: Factory.rive,
    );
  }

  void _initTts() async {}

  void _onRiveLoaded(RiveLoaded loaded) {
    _controller = loaded.controller;
    _viewModel = _controller?.dataBind(DataBind.auto());
    debugPrint(
      "Bağlantı: ${_viewModel != null ? 'TAMAM' : 'ViewModel Bulunamadı'}",
    );

    // İlk açılışta ağzı kapalı başlasın
    _updateRiveProperty("talk", false);
    _updateRiveProperty("visemeNum", 0.0);
    _updateRiveProperty("duration", 200.0);
  }

  void _updateRiveProperty(String name, dynamic value) {
    final vm = _viewModel;
    if (vm == null) return;

    try {
      if (name == "talk" && value is bool) {
        vm.boolean(name)?.value = value;
      } else if ((name == "visemeNum" || name == "duration") &&
          (value is double || value is int)) {
        vm.number(name)?.value = value.toDouble();
      }
      return;
    } catch (_) {
      // Fallback
      try {
        for (final prop in vm.properties) {
          if (prop.name == name) {
            (prop as dynamic).value = value;
            return;
          }
        }
      } catch (e2) {
        debugPrint("Hata: $e2");
      }
    }
  }


  // TTS + konuşma animasyonu
  

  Future<void> _startSpeaking() async {
    if (_isTalking) {
      _stopSpeakingAnimation();
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _stopVisemeLoop();

    // Önceki timer'ları temizle
    _visemeTimers.forEach((timer) => timer.cancel());
    _visemeTimers.clear();

    setState(() {
      _isTalking = true;
      _selectedViseme = 0;
    });

    // Talk'u aktif et
    //  _updateRiveProperty("talk", true);

    // Ses dosyasını çal
    AudioPlayer player = AudioPlayer();
    try {
      await player.play(AssetSource("labs.mp3"));
    } catch (e) {
      debugPrint("Ses çalma hatası: $e");
    }

    // Her viseme için zamanlanmış timer oluştur
    for (var i = 0; i < visemes.length; i++) {
      final viseme = visemes[i];
      final timeInSeconds = viseme["time"] as num;
      final visemeId = viseme["id"] as int;

      // Zamanlamayı milisaniyeye çevir
      final delay = Duration(milliseconds: (timeInSeconds * 1000).round());

      // Her viseme için timer oluştur
      final timer = Timer(delay, () {
        if (!_isTalking) return; // Eğer konuşma durdurulduysa devam etme

        _updateRiveProperty("visemeNum", visemeId.toDouble());
        _updateRiveProperty("visemdurationeNum", timeInSeconds.toDouble());
        debugPrint("✅ Viseme ${visemeId} ayarlandı (zaman: ${timeInSeconds}s)");

        // Son viseme ise konuşmayı bitir
        if (i == visemes.length - 1) {
          // Son viseme'den sonra kısa bir gecikme ile talk'u kapat
          Timer(const Duration(milliseconds: 200), () {
            if (mounted && _isTalking) {
              _stopSpeakingAnimation();
            }
          });
        }
      });

      _visemeTimers.add(timer);
    }

    // İlk viseme'i hemen ayarla (time: 0)
    if (visemes.isNotEmpty && visemes[0]["time"] == 0) {
      _updateRiveProperty("visemeNum", (visemes[0]["id"] as int).toDouble());
      debugPrint("✅ İlk viseme ${visemes[0]["id"]} ayarlandı (zaman: 0s)");
    }
  }

  void _stopSpeakingAnimation() {
    // Tüm viseme timer'larını iptal et
    _visemeTimers.forEach((timer) => timer.cancel());
    _visemeTimers.clear();

    _talkTimer?.cancel();

    if (mounted) {
      setState(() => _isTalking = false);
    }

    _updateRiveProperty("talk", false);
    _updateRiveProperty("visemeNum", 0.0);
    _updateRiveProperty("duration", 200.0);
  }

  // =========================
  // VISeme Test (7 buton + loop)
  // =========================
  // 1) Tek viseme basınca: loop + tts timer tamamen dursun
  void _setViseme(int v) {
    // konuşma varsa durdur
    if (_isTalking) {
      _stopSpeakingAnimation();
    }
    _stopVisemeLoop();

    setState(() => _selectedViseme = v);

    // TEK VISEME TEST MODU:
    _updateRiveProperty("talk", false);

    _updateRiveProperty("duration", 200.0);
    _updateRiveProperty("visemeNum", v.toDouble());

    Future.delayed(const Duration(milliseconds: 30), () {
      _updateRiveProperty("talk", true);
      Future.delayed(const Duration(milliseconds: 30), () {
        _updateRiveProperty("talk", false);
      });
    });
  }

  void _toggleVisemeLoop() {
    if (_isTalking) {
      _stopSpeakingAnimation();
    }

    if (_isVisemeLooping) {
      _stopVisemeLoop();
      // loop durunca ağzı kapat
      _updateRiveProperty("talk", false);
      _updateRiveProperty("visemeNum", 0.0);
      return;
    }

    setState(() => _isVisemeLooping = true);

    _updateRiveProperty("talk", true);
    _updateRiveProperty("duration", 200.0);

    _visemeLoopTimer?.cancel();
    _visemeLoopTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final next = (_selectedViseme + 1) % 7; // 0..6
      setState(() => _selectedViseme = next);
      _updateRiveProperty("visemeNum", next.toDouble());
    });
  }

  void _stopVisemeLoop() {
    _visemeLoopTimer?.cancel();
    if (mounted) setState(() => _isVisemeLooping = false);
  }

  @override
  void dispose() {
    _talkTimer?.cancel();
    _visemeLoopTimer?.cancel();
    _visemeTimers.forEach((timer) => timer.cancel());
    _visemeTimers.clear();
    _fileLoader.dispose();
    _textController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "3D AVATAR TEST",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: RiveWidgetBuilder(
              fileLoader: _fileLoader,
              artboardSelector: ArtboardSelector.byName("MainArtboard"),
              stateMachineSelector: StateMachineSelector.byName(
                "State Machine 1",
              ),
              onLoaded: _onRiveLoaded,
              builder: (context, state) => switch (state) {
                RiveLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                RiveFailed() => Center(
                  child: Text(
                    "Hata: ${state.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                RiveLoaded() => RiveWidget(
                  controller: state.controller,
                  fit: Fit.contain,
                ),
              },
            ),
          ),
          _buildInputPanel(),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Konuşulacak metni yazın...",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TTS Button
          SizedBox(
            width: double.infinity,
            height: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTalking
                    ? Colors.redAccent
                    : Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: _isTalking ? _stopSpeakingAnimation : _startSpeaking,
              icon: Icon(
                _isTalking ? Icons.stop_circle : Icons.play_circle_filled,
                size: 26,
              ),
              label: Text(
                _isTalking ? "KONUŞMAYI DURDUR" : "METNİ SESLENDİR",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 7 viseme button + 1. loop button
          Wrap(
            spacing: 1,
            runSpacing: 1,
            children: [
              ...List.generate(7, (i) {
                final selected = _selectedViseme == i && !_isVisemeLooping;
                return FilledButton.tonal(
                  onPressed: () => _setViseme(i),
                  child: Text(selected ? "viseme $i ✅" : "viseme $i"),
                );
              }),
              FilledButton(
                onPressed: _toggleVisemeLoop,
                style: FilledButton.styleFrom(
                  backgroundColor: _isVisemeLooping
                      ? Colors.redAccent
                      : Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isVisemeLooping ? "LOOP DURDUR" : "LOOP BAŞLAT"),
              ),
              FilledButton.tonal(
                onPressed: () {
                  _stopVisemeLoop();
                  if (_isTalking) {
                    _stopSpeakingAnimation();
                  }
                  setState(() => _selectedViseme = 0);
                  _updateRiveProperty("talk", false);
                  _updateRiveProperty("visemeNum", 0.0);
                  _updateRiveProperty("duration", 200.0);
                },
                child: const Text("RESET"),
              ),
            ],
          ),

          const SizedBox(height: 1),
        ],
      ),
    );
  }
}
