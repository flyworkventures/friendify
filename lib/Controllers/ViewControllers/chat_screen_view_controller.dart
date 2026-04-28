// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Models/chat_model.dart';
import 'package:friendfy/Models/message_model.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class ChatScreenViewController extends StateNotifier<ChatScreenViewModel> {
  Ref? ref;
  ChatScreenViewController(this.ref) : super(ChatScreenViewModel());
  bool loadingScreen = false;
  TextEditingController messageController = TextEditingController();
  RecorderController recorderController = RecorderController();
  final ImagePicker _picker = ImagePicker();
  XFile? selectedImage;
  DateTime? _recordingStartTime; // Kayıt başlangıç zamanı

  getConversations() async {
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(
      path: AppConstants.getConversations,
      body: {"userId": ref?.read(AllControllers.userController)?.id},
    );

    if (res.statusCode == 200) {
      List jsonList = jsonDecode(res.body);
      List<ConversationModel> messages = jsonList
          .map(
            (a) => ConversationModel(
              chatModel: ChatModel.fromMap(a["conversationData"]),
              agentModel: AgentModel.fromMap(a["botData"]),
            ),
          )
          .toList();
      debugPrint(messages.toSet().toString());
      state = state.copyWith(
        conversations: messages,
        filteredConversations: messages,
        isSearching: false,
      );
    } else {
      log("Mesajlar getirilirken hata oluştu");
    }
  }

  searchConversations(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(
        filteredConversations: state.conversations,
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(isSearching: true);
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(
      path: AppConstants.searchConversations,
      body: {
        "userId": ref?.read(AllControllers.userController)?.id,
        "searchQuery": query,
      },
    );

    if (res.statusCode == 200) {
      List jsonList = jsonDecode(res.body);
      List<ConversationModel> filteredMessages = jsonList
          .map(
            (a) => ConversationModel(
              chatModel: ChatModel.fromMap(a["conversationData"]),
              agentModel: AgentModel.fromMap(a["botData"]),
            ),
          )
          .toList();
      state = state.copyWith(filteredConversations: filteredMessages);
    } else {
      log("Arama sırasında hata oluştu");
      state = state.copyWith(filteredConversations: []);
    }
  }

  changeChatModel(ChatModel chatModel, AgentModel agent) {
    state = state.copyWith(chatModel: chatModel, agent: agent);
  }

  getMessages() async {
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(
      path: AppConstants.getMessage,
      body: {"conversationId": state.chatModel?.id},
    );
    if (res.statusCode == 200) {
      List messagesJson = jsonDecode(res.body);
      List<MessageModel> messages = messagesJson
          .map((a) => MessageModel.fromMap(a))
          .toList();

      // Mesajları createdAt'e göre sırala (en eski üstte)
      messages.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.createdAt);
          final dateB = DateTime.parse(b.createdAt);
          return dateA.compareTo(dateB);
        } catch (e) {
          log("Error parsing dates: $e");
          return 0;
        }
      });

      state = state.copyWith(messages: messages);
    } else {
      log("Mesajlar getirilirken hata oluştu");
    }
  }

  listenMessages() async {
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(
      path: AppConstants.listenMessage,
      body: {"conversationId": state.chatModel?.id},
    );
    if (res.statusCode == 200) {
      var json = jsonDecode(res.body);
      // debugPrint(json.toString());
      List messagesJson = json["messages"];
      List<MessageModel> messages = messagesJson
          .map((a) => MessageModel.fromMap(a))
          .toList();
      final oldMessages = state.messages ?? [];
      final newMessages = messages;

      // aynı id'ye sahip mesajları filtrele
      final mergedMessages = [
        ...oldMessages,
        ...newMessages.where((m) => !oldMessages.any((old) => old.id == m.id)),
      ];

      // Mesajları createdAt'e göre sırala (en eski üstte)
      mergedMessages.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.createdAt);
          final dateB = DateTime.parse(b.createdAt);
          return dateA.compareTo(dateB);
        } catch (e) {
          log("Error parsing dates: $e");
          return 0;
        }
      });

      ChatState chatState = _chatStateFormatter(json["conversation_state"]);
      state = state.copyWith(chatState: chatState, messages: mergedMessages);
      // Sadece mesajlar varsa debug print yap
      if (state.messages != null && state.messages!.isNotEmpty) {
        debugPrint(state.messages!.last.createdAt.toString());
      }
    } else {
      log("Mesajlar getirilirken hata oluştu");
    }
  }

  /// Premium kontrolü yapar ve mesaj gönderebilir mi kontrol eder
  Future<bool> _canSendMessage() async {
    final user = ref?.read(AllControllers.userController);

    log("🔍 [PREMIUM CHECK] Mesaj gönderme kontrolü başladı");
    log("👤 [PREMIUM CHECK] User ID: ${user?.id}, Email: ${user?.email}");

    // Premium kontrolü
    final isPremium = PremiumService.isPremiumActive(user);
    log("💎 [PREMIUM CHECK] Premium aktif mi: $isPremium");

    if (isPremium) {
      log("✅ [PREMIUM CHECK] Premium üye - Sınırsız mesaj gönderebilir");
      return true; // Premium üye sınırsız mesaj gönderebilir
    }

    // Günlük mesaj limiti kontrolü (free trial dahil)
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final todayMessageCount = await localService.getDailyMessageCount();
    final limit = PremiumService.getDailyMessageLimit(user);

    log("📊 [PREMIUM CHECK] Bugünkü mesaj sayısı: $todayMessageCount");
    log("📊 [PREMIUM CHECK] Günlük mesaj limiti: $limit");

    if (limit != null && todayMessageCount >= limit) {
      log(
        "❌ [PREMIUM CHECK] Günlük mesaj limiti aşıldı! ($todayMessageCount >= $limit)",
      );

      // Misafir kullanıcı ise oturum açma ekranına yönlendir
      if (user?.credential == "guest") {
        await _showGuestLimitDialog();
        return false;
      }

      // Free trial veya normal kullanıcı ise premium ekranına yönlendir
      try {
        log("💳 [PREMIUM CHECK] Premium ekranı açılıyor...");
        await RevenueCatUI.presentPaywall();
        log("✅ [PREMIUM CHECK] Premium ekranı açıldı");
      } catch (e) {
        log("⚠️ [PREMIUM CHECK] Premium ekranı açılamadı: $e");
      }
      return false;
    }

    log(
      "✅ [PREMIUM CHECK] Mesaj gönderebilir (${todayMessageCount + 1}/$limit)",
    );
    return true;
  }

  /// Fotoğraf gönderebilir mi kontrol eder
  Future<bool> _canSendPhoto() async {
    final user = ref?.read(AllControllers.userController);

    log("🔍 [PREMIUM CHECK] Fotoğraf gönderme kontrolü başladı");

    // Premium kontrolü
    final isPremium = PremiumService.isPremiumActive(user);
    log("💎 [PREMIUM CHECK] Premium aktif mi: $isPremium");

    if (isPremium) {
      log("✅ [PREMIUM CHECK] Premium üye - Sınırsız fotoğraf gönderebilir");
      return true;
    }

    // Günlük fotoğraf limiti kontrolü (free trial dahil)
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final todayPhotoCount = await localService.getDailyPhotoCount();
    final limit = PremiumService.getDailyPhotoLimit(user);

    log("📸 [PREMIUM CHECK] Bugünkü fotoğraf sayısı: $todayPhotoCount");
    log("📸 [PREMIUM CHECK] Günlük fotoğraf limiti: $limit");

    final canSend = PremiumService.canSendPhoto(user, todayPhotoCount);

    if (!canSend) {
      log(
        "❌ [PREMIUM CHECK] Günlük fotoğraf limiti aşıldı! ($todayPhotoCount >= $limit)",
      );

      // Misafir kullanıcı ise oturum açma ekranına yönlendir
      if (user?.credential == "guest") {
        await _showGuestLimitDialog();
        return false;
      }

      // Free trial veya normal kullanıcı ise premium ekranına yönlendir
      try {
        log("💳 [PREMIUM CHECK] Premium ekranı açılıyor...");
        await RevenueCatUI.presentPaywall();
        log("✅ [PREMIUM CHECK] Premium ekranı açıldı");
      } catch (e) {
        log("⚠️ [PREMIUM CHECK] Premium ekranı açılamadı: $e");
      }
      return false;
    }

    log(
      "✅ [PREMIUM CHECK] Fotoğraf gönderebilir (${todayPhotoCount + 1}/$limit)",
    );
    return true;
  }

  /// Misafir kullanıcı için günlük mesaj limiti aşıldığında dialog göster
  Future<void> _showGuestLimitDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            Translate.translate(TranslateKeys.dailyMessageLimitTitle, context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            Translate.translate(
              TranslateKeys.dailyMessageLimitMessage,
              context,
            ),
            style: GoogleFonts.quicksand(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Onboard ekranına yönlendir
                navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  '/onboard',
                  (route) => false,
                );
              },
              child: Text(
                Translate.translate(
                  TranslateKeys.pleaseLoginToContinue,
                  context,
                ),
                style: GoogleFonts.quicksand(
                  color: MyColors.purple,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  sendMessage() async {
    // Premium ve limit kontrolü
    final canSend = await _canSendMessage();
    if (!canSend) {
      state = state.copyWith(responseWaiting: false);
      return;
    }

    HttpService httpService = HttpService(ref: ref);
    state = state.copyWith(responseWaiting: true);

    String message = messageController.text.trim();

    // Eğer resim varsa, resim gönder
    if (selectedImage != null) {
      log("📸 [IMAGE] Fotoğraf gönderme kontrolü yapılıyor...");

      // Fotoğraf gönderme kontrolü
      final canSendPhoto = await _canSendPhoto();
      if (!canSendPhoto) {
        log(
          "❌ [IMAGE] Fotoğraf gönderilemedi - Limit aşıldı veya premium gerekli",
        );
        state = state.copyWith(responseWaiting: false);
        return;
      }

      log("📸 [IMAGE] Fotoğraf gönderme başlatılıyor...");

      try {
        var res = await httpService.postImageFile(
          path: AppConstants.sendImageMessage,
          file: File(selectedImage!.path),
          conversation: state.chatModel?.id.toString() ?? "",
          message: message.isEmpty ? null : message,
        );

        if (res != null && res.statusCode == 200) {
          log("✅ [IMAGE] Fotoğraf başarıyla gönderildi");
          messageController.clear();
          selectedImage = null;
          state = state.copyWith(image: null);

          // Günlük fotoğraf sayısını artır
          final prefs = await SharedPreferences.getInstance();
          final localService = LocalService(prefs: prefs);
          await localService.incrementDailyPhotoCount();
          log("📊 [IMAGE] Günlük fotoğraf sayacı artırıldı");

          // Conversation listesini güncelle
          getConversations();
        } else if (res != null && res.statusCode == 403) {
          // Misafir kullanıcı günlük limit hatası
          try {
            final body = await res.stream.bytesToString();
            final errorJson = jsonDecode(body);
            if (errorJson["error"] == "GUEST_MESSAGE_LIMIT") {
              await _showGuestLimitDialog();
            }
          } catch (e) {
            log("Error parsing error response: $e");
          }
          log(
            "❌ [IMAGE] Fotoğraf gönderilemedi - HTTP Status: ${res.statusCode}",
          );
        } else {
          log(
            "❌ [IMAGE] Fotoğraf gönderilemedi - HTTP Status: ${res?.statusCode}",
          );
        }
      } catch (e) {
        log("❌ [IMAGE] Fotoğraf gönderilirken hata: $e");
      }

      state = state.copyWith(responseWaiting: false);
    } else if (message.isNotEmpty) {
      // Normal text mesaj gönder
      messageController.clear();
      var res = await httpService.post(
        path: AppConstants.sendMessage,
        body: {
          "message": message,
          "conversationId": state.chatModel?.id,
          "sender": "user",
          "userId": ref?.read(AllControllers.userController)?.id,
        },
      );

      if (res.statusCode == 200) {
        // Günlük mesaj sayısını artır
        final prefs = await SharedPreferences.getInstance();
        final localService = LocalService(prefs: prefs);
        await localService.incrementDailyMessageCount();

        // Conversation listesini güncelle
        getConversations();
      } else if (res.statusCode == 403) {
        // Misafir kullanıcı günlük limit hatası
        try {
          final errorJson = jsonDecode(res.body);
          if (errorJson["error"] == "GUEST_MESSAGE_LIMIT") {
            await _showGuestLimitDialog();
          }
        } catch (e) {
          log("Error parsing error response: $e");
        }
      }

      state = state.copyWith(responseWaiting: false);
    } else {
      state = state.copyWith(responseWaiting: false);
    }
  }

  ChatState _chatStateFormatter(String state) {
    if (state == "bot_typing") {
      return ChatState.botWriting;
    } else if (state == "bot_record_audio") {
      return ChatState.botAudioRecording;
    } else {
      return ChatState.normal;
    }
  }

  pushFromMessages(ChatModel chatModel, AgentModel selectedAgent) async {
    changeChatModel(chatModel, selectedAgent);
    await navigatorKey.currentState?.pushNamed("/chatView");
  }

  sendAudio(String path) async {
    // Sesli mesaj limiti kontrolü (ÖNCE kontrol et, sonra gönder)
    final canSendAudio = await _canSendAudio();
    if (!canSendAudio) {
      log("❌ [AUDIO] Sesli mesaj gönderilemedi - Limit kontrolü başarısız");
      state = state.copyWith(responseWaiting: false);
      return;
    }

    log("✅ [AUDIO] Sesli mesaj limiti kontrolü başarılı, gönderiliyor...");

    HttpService httpService = HttpService(ref: ref);
    state = state.copyWith(responseWaiting: true);
    messageController.clear();

    var res = await httpService.postAudioFile(
      path: AppConstants.sendAudioMessage,
      file: File(path),
      conversation: state.chatModel?.id.toString(),
    );

    if (res != null && res.statusCode == 200) {
      // Günlük sesli mesaj sayısını artır
      final prefs = await SharedPreferences.getInstance();
      final localService = LocalService(prefs: prefs);
      await localService.incrementDailyAudioCount();

      // Conversation listesini güncelle
      getConversations();
    } else if (res != null && res.statusCode == 403) {
      // Sesli mesaj limiti hatası
      try {
        final body = await res.stream.bytesToString();
        final errorJson = jsonDecode(body);
        final errorType = errorJson["error"];

        log("❌ [AUDIO] Backend'den limit hatası: $errorType");

        if (errorType == "GUEST_MESSAGE_LIMIT" ||
            errorType == "AUDIO_MESSAGE_LIMIT") {
          final user = ref?.read(AllControllers.userController);

          // Misafir kullanıcı ise oturum açma ekranına yönlendir
          if (user?.credential == "guest") {
            await _showGuestLimitDialog();
          } else {
            // Standart paket veya free trial kullanıcı ise premium ekranına yönlendir
            try {
              log("💳 [AUDIO] Premium ekranı açılıyor...");
              await RevenueCatUI.presentPaywall();
              log("✅ [AUDIO] Premium ekranı açıldı");
            } catch (e) {
              log("⚠️ [AUDIO] Premium ekranı açılamadı: $e");
            }
          }
        }
      } catch (e) {
        log("Error parsing error response: $e");
        // Hata parse edilemezse bile premium ekranını göster
        try {
          await RevenueCatUI.presentPaywall();
        } catch (e) {
          log("⚠️ [AUDIO] Premium ekranı açılamadı: $e");
        }
      }
    }

    state = state.copyWith(responseWaiting: false);
  }

  /// Sesli mesaj gönderebilir mi kontrol eder
  Future<bool> _canSendAudio() async {
    final user = ref?.read(AllControllers.userController);

    log("🔍 [AUDIO CHECK] Sesli mesaj gönderme kontrolü başladı");
    log("👤 [AUDIO CHECK] User ID: ${user?.id}, Email: ${user?.email}");
    log("👤 [AUDIO CHECK] User credential: ${user?.credential}");

    // Premium kontrolü
    final isPremium = PremiumService.isPremiumActive(user);
    log("💎 [AUDIO CHECK] Premium aktif mi: $isPremium");

    if (isPremium) {
      log("✅ [AUDIO CHECK] Premium üye - Sınırsız sesli mesaj gönderebilir");
      return true; // Premium üye sınırsız sesli mesaj gönderebilir
    }

    // Free trial kontrolü
    final canUseTrial = PremiumService.canUseFreeTrial(user);
    log("🎁 [AUDIO CHECK] Free trial kullanılabilir mi: $canUseTrial");

    // Günlük sesli mesaj limiti kontrolü
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final todayAudioCount = await localService.getDailyAudioCount();
    final limit = PremiumService.getDailyAudioLimit(user);

    log("📊 [AUDIO CHECK] Bugünkü sesli mesaj sayısı: $todayAudioCount");
    log("📊 [AUDIO CHECK] Günlük sesli mesaj limiti: $limit");
    log(
      "📊 [AUDIO CHECK] Limit kontrolü: ${limit != null ? '$todayAudioCount >= $limit' : 'limit null'}",
    );

    // Limit kontrolü (free trial dahil)
    if (limit != null && todayAudioCount >= limit) {
      log(
        "❌ [AUDIO CHECK] Günlük sesli mesaj limiti aşıldı! ($todayAudioCount >= $limit)",
      );

      // Misafir kullanıcı ise oturum açma ekranına yönlendir
      if (user?.credential == "guest") {
        await _showGuestLimitDialog();
        return false;
      }

      // Free trial veya normal kullanıcı ise premium ekranına yönlendir
      try {
        log("💳 [AUDIO CHECK] Premium ekranı açılıyor...");
        await RevenueCatUI.presentPaywall();
        log("✅ [AUDIO CHECK] Premium ekranı açıldı");
      } catch (e) {
        log("⚠️ [AUDIO CHECK] Premium ekranı açılamadı: $e");
      }
      return false;
    }

    log(
      "✅ [AUDIO CHECK] Sesli mesaj gönderebilir (${todayAudioCount + 1}/$limit)",
    );
    return true;
  }

  audioButton() async {
    if (state.recordState == RecordState.none) {
      await recordAudio();
    } else if (state.recordState == RecordState.stopped) {
      // Stopped state'inde audioButton çağrılırsa iptal et
      cancelStoppedRecording();
    } else if (state.recordState == RecordState.recording) {
      await stoppingAudio();
    }
  }

  /// Instagram tarzı: Basıldığında kayıt başlat
  Future<void> startRecording() async {
    if (state.recordState == RecordState.recording) {
      return; // Zaten kayıt yapılıyor
    }

    if (recorderController.hasPermission) {
      _recordingStartTime = DateTime.now(); // Kayıt başlangıç zamanını kaydet
      await recorderController.record();
      state = state.copyWith(recordState: RecordState.recording);
      log("🎤 Recording started");
    } else {
      await recorderController.checkPermission();
      // İzin verildiyse tekrar dene
      if (recorderController.hasPermission) {
        _recordingStartTime = DateTime.now(); // Kayıt başlangıç zamanını kaydet
        await recorderController.record();
        state = state.copyWith(recordState: RecordState.recording);
        log("🎤 Recording started after permission granted");
      }
    }
  }

  /// Instagram tarzı: Bırakıldığında kayıt durdur ve gönder
  Future<void> stopRecordingAndSend() async {
    log(
      "🎤 stopRecordingAndSend çağrıldı. Current state: ${state.recordState}, isRecording: ${recorderController.isRecording}",
    );

    if (state.recordState != RecordState.recording) {
      log("⚠️ Kayıt yapılmıyor, state: ${state.recordState}");
      return; // Kayıt yapılmıyor
    }

    if (recorderController.isRecording) {
      log("🎤 Kayıt durduruluyor...");
      String? path = await recorderController.stop();
      log("🎤 Kayıt durduruldu. Path: $path");

      // State'i hemen güncelle (UI'ın güncellenmesi için)
      state = state.copyWith(recordState: RecordState.none);

      if (path != null) {
        log("🎤 Audio recorded. Path: $path");
        // Minimum kayıt süresi kontrolü (0.5 saniye)
        if (_recordingStartTime != null) {
          final duration = DateTime.now().difference(_recordingStartTime!);
          log("🎤 Kayıt süresi: ${duration.inMilliseconds}ms");
          if (duration.inMilliseconds > 500) {
            // Yeterli süre kaydedildi, gönder
            log("🎤 Kayıt gönderiliyor...");
            await sendAudio(path);
          } else {
            log(
              "⚠️ Recording too short (${duration.inMilliseconds}ms), cancelled",
            );
            // Çok kısa kayıt, iptal et (state zaten none)
          }
        } else {
          // Başlangıç zamanı yoksa gönder (fallback)
          log("🎤 Başlangıç zamanı yok, gönderiliyor...");
          await sendAudio(path);
        }
        _recordingStartTime = null; // Temizle
      } else {
        log("⚠️ No audio path returned");
        _recordingStartTime = null; // Temizle
      }
    } else {
      log("⚠️ RecorderController.isRecording false, state güncelleniyor");
      state = state.copyWith(recordState: RecordState.none);
      _recordingStartTime = null; // Temizle
    }

    log("✅ stopRecordingAndSend tamamlandı. Final state: ${state.recordState}");
  }

  /// Instagram tarzı: İptal edildiğinde kayıt durdur (gönderme)
  Future<void> cancelRecording() async {
    if (state.recordState != RecordState.recording) {
      return; // Kayıt yapılmıyor
    }

    if (recorderController.isRecording) {
      await recorderController.stop();
      log("🎤 Recording cancelled");
      state = state.copyWith(recordState: RecordState.none);
      _recordingStartTime = null; // Temizle
    }
  }

  recordAudio() async {
    if (recorderController.hasPermission) {
      await recorderController.record();
      state = state.copyWith(recordState: RecordState.recording);
    } else {
      await recorderController.checkPermission();
    }
  }

  stoppingAudio() async {
    if (recorderController.isRecording) {
      String? path = await recorderController.stop();
      if (path != null) {
        log("🎤 Audio recorded. Path: $path - Stopped, waiting for send");
        // Kaydı durdur ama gönderme - path'i state'e kaydet
        state = state.copyWith(
          recordState: RecordState.stopped,
          recordedAudioPath: path,
        );
      } else {
        log("⚠️ No audio path returned");
        state = state.copyWith(recordState: RecordState.none);
      }
      _recordingStartTime = null; // Temizle
    }
  }

  /// Durdurulmuş kaydı gönder
  Future<void> sendStoppedRecording() async {
    if (state.recordedAudioPath != null &&
        state.recordState == RecordState.stopped) {
      final path = state.recordedAudioPath!;
      log("🎤 Sending stopped recording. Path: $path");
      // State'i temizle
      state = state.copyWith(
        recordState: RecordState.none,
        recordedAudioPath: null,
      );
      // Sesli mesajı gönder
      await sendAudio(path);
    }
  }

  /// Durdurulmuş kaydı iptal et
  void cancelStoppedRecording() {
    if (state.recordState == RecordState.stopped) {
      log("🎤 Cancelling stopped recording");
      // State'i temizle
      state = state.copyWith(
        recordState: RecordState.none,
        recordedAudioPath: null,
      );
      _recordingStartTime = null; // Temizle
    }
  }

  // Report Conversation
  Future<bool> sendReport(String reason, String description) async {
    try {
      HttpService httpService = HttpService(ref: ref);

      final response = await httpService.post(
        path: AppConstants.reportConversation,
        body: {
          'userId': ref?.read(AllControllers.userController)?.id,
          'conversationId': state.chatModel?.id,
          'botId': state.agent?.id,
          'reason': reason,
          'description': description,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Error sending report: $e');
      return false;
    }
  }

  // Delete Conversation
  Future<bool> deleteConversation() async {
    try {
      HttpService httpService = HttpService(ref: ref);

      final response = await httpService.post(
        path: AppConstants.deleteConversation,
        body: {
          'conversationId': state.chatModel?.id,
          'userId': ref?.read(AllControllers.userController)?.id,
        },
      );

      if (response.statusCode == 200) {
        // Refresh conversations list after deletion
        await getConversations();
        return true;
      }

      return false;
    } catch (e) {
      log('Error deleting conversation: $e');
      return false;
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        log("Image selected: ${image.path}");
        state = state.copyWith(image: image);
        selectedImage = image;
      }
    } catch (e) {
      log("Error picking image: $e");
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      log("📷 [CAMERA] Kamera açılıyor...");
      // ImagePicker'ın native preview ekranını atlamak için direkt kamera açıyoruz
      // Fotoğraf çekildikten sonra özel preview ekranımızı gösteriyoruz
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        log("✅ [CAMERA] Fotoğraf seçildi: ${image.path}");
        // Fotoğraf çekildi, şimdi özel preview ekranını göster
        final context = navigatorKey.currentContext;
        if (context != null) {
          final usePhoto = await _showCameraPreview(context, image);
          if (usePhoto == true) {
            // Kullanıcı "Fotoğrafı Kullan" dedi
            state = state.copyWith(image: image);
            selectedImage = image;
          } else if (usePhoto == false) {
            // Kullanıcı "Yeniden Çek" dedi, tekrar kamera aç
            await pickImageFromCamera(); // Recursive call
          }
          // usePhoto == null ise kullanıcı dialog'u kapattı, hiçbir şey yapma
        } else {
          // Context yoksa direkt kullan
          state = state.copyWith(image: image);
          selectedImage = image;
        }
      } else {
        log("ℹ️ [CAMERA] Kullanıcı fotoğraf çekmeyi iptal etti");
      }
    } catch (e, stackTrace) {
      log("❌ [CAMERA] Kamera hatası: $e");
      log("❌ [CAMERA] Stack trace: $stackTrace");

      // Hata mesajını kullanıcıya göster
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Translate.translate(TranslateKeys.cameraOpenError, context),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Özel kamera preview ekranı - "Yeniden Çek" ve "Fotoğrafı Kullan" butonları ile
  Future<bool?> _showCameraPreview(
    BuildContext context,
    XFile imageFile,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.black,
            child: Stack(
              children: [
                // Fotoğraf önizlemesi
                Center(
                  child: Image.file(File(imageFile.path), fit: BoxFit.contain),
                ),
                // Alt butonlar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 30.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Yeniden Çek butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(
                                dialogContext,
                              ).pop(false); // false = yeniden çek
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 15.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30.r),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  Translate.translate(
                                    TranslateKeys.retake,
                                    context,
                                  ),
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20.w),
                        // Fotoğrafı Kullan butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(
                                dialogContext,
                              ).pop(true); // true = kullan
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 15.h),
                              decoration: BoxDecoration(
                                color: MyColors.purple,
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Center(
                                child: Text(
                                  Translate.translate(
                                    TranslateKeys.usePhoto,
                                    context,
                                  ),
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        );
      },
    );
  }

  removeImage() async {
    selectedImage = null;
    state = state.copyWith(image: null);
    debugPrint("Clicked remove Image: ${state.image?.path}");
  }
}

class ConversationModel {
  final ChatModel? chatModel;
  final AgentModel? agentModel;
  ConversationModel({this.chatModel, this.agentModel});

  ConversationModel copyWith({ChatModel? chatModel, AgentModel? agentModel}) {
    return ConversationModel(
      chatModel: chatModel ?? this.chatModel,
      agentModel: agentModel ?? this.agentModel,
    );
  }
}

class ChatScreenViewModel {
  final ChatModel? chatModel;
  final AgentModel? agent;
  final List<MessageModel>? messages;
  final ChatState chatState;
  final bool? responseWaiting;
  final List<ConversationModel>? conversations;
  final List<ConversationModel>? filteredConversations;
  final bool isSearching;
  final RecordState recordState;
  final XFile? image;
  final String? recordedAudioPath; // Durdurulmuş kayıt path'i
  ChatScreenViewModel({
    this.chatModel,
    this.agent,
    this.messages,
    this.chatState = ChatState.normal,
    this.responseWaiting = false,
    this.conversations,
    this.filteredConversations,
    this.isSearching = false,
    this.recordState = RecordState.none,
    this.image,
    this.recordedAudioPath,
  });

  ChatScreenViewModel copyWith({
    ChatModel? chatModel,
    AgentModel? agent,
    List<MessageModel>? messages,
    ChatState? chatState,
    bool? responseWaiting,
    List<ConversationModel>? conversations,
    List<ConversationModel>? filteredConversations,
    bool? isSearching,
    RecordState? recordState,
    Object? image = const _Sentinel(),
    Object? recordedAudioPath =
        const _Sentinel(), // Object? kullanarak null değerini set edebilmek için
  }) {
    return ChatScreenViewModel(
      chatModel: chatModel ?? this.chatModel,
      agent: agent ?? this.agent,
      messages: messages ?? this.messages,
      chatState: chatState ?? ChatState.normal,
      responseWaiting: responseWaiting ?? this.responseWaiting,
      conversations: conversations ?? this.conversations,
      filteredConversations:
          filteredConversations ?? this.filteredConversations,
      isSearching: isSearching ?? this.isSearching,
      recordState: recordState ?? this.recordState,
      image: image is _Sentinel ? this.image : (image as XFile?),
      recordedAudioPath: recordedAudioPath is _Sentinel
          ? this.recordedAudioPath
          : (recordedAudioPath as String?),
    );
  }
}

enum ChatState { normal, botWriting, botAudioRecording }

enum RecordState { recording, stopped, none }

class _Sentinel {
  const _Sentinel();
} // Null'ı açıkça set etmek için özel bir sınıf
