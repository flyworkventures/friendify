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
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class ChatScreenViewController extends StateNotifier<ChatScreenViewModel>{
  Ref? ref;
  ChatScreenViewController(this.ref) : super(ChatScreenViewModel());
  bool loadingScreen = false;
  TextEditingController messageController = TextEditingController();
 RecorderController recorderController = RecorderController();
 final ImagePicker _picker = ImagePicker();
XFile? selectedImage;

  
  getConversations()async{
      HttpService httpService = HttpService(ref: ref);
  var res = await httpService.post(path: AppConstants.getConversations,body: {"userId": ref?.read(AllControllers.userController)?.id});

  if (res.statusCode == 200) {
      List jsonList = jsonDecode(res.body);
    List<ConversationModel> messages = jsonList.map((a) => ConversationModel(chatModel: ChatModel.fromMap(a["conversationData"]),agentModel: AgentModel.fromMap(a["botData"]))).toList();
    debugPrint(messages.toSet().toString());
    state = state.copyWith(conversations: messages, filteredConversations: messages, isSearching: false);
  }else{
    log("Mesajlar getirilirken hata oluştu");
  }
  }

  searchConversations(String query)async{
    if (query.trim().isEmpty) {
      state = state.copyWith(filteredConversations: state.conversations, isSearching: false);
      return;
    }
    
    state = state.copyWith(isSearching: true);
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(
      path: AppConstants.searchConversations,
      body: {
        "userId": ref?.read(AllControllers.userController)?.id,
        "searchQuery": query
      }
    );

    if (res.statusCode == 200) {
      List jsonList = jsonDecode(res.body);
      List<ConversationModel> filteredMessages = jsonList.map((a) => ConversationModel(
        chatModel: ChatModel.fromMap(a["conversationData"]),
        agentModel: AgentModel.fromMap(a["botData"])
      )).toList();
      state = state.copyWith(filteredConversations: filteredMessages);
    } else {
      log("Arama sırasında hata oluştu");
      state = state.copyWith(filteredConversations: []);
    }
  }

  changeChatModel(ChatModel chatModel,AgentModel agent){

    state = state.copyWith(chatModel: chatModel,agent: agent);
  }


  getMessages()async{
  HttpService httpService = HttpService(ref: ref);
  var res = await httpService.post(path: AppConstants.getMessage,body: {"conversationId":state.chatModel?.id});
  if (res.statusCode == 200) {
    List messagesJson = jsonDecode(res.body);
    List<MessageModel> messages = messagesJson.map((a) => MessageModel.fromMap(a)).toList();
    state = state.copyWith(messages: messages);
  }else{
    log("Mesajlar getirilirken hata oluştu");
  }
  }

    listenMessages()async{
  HttpService httpService = HttpService(ref: ref);
  var res = await httpService.post(path: AppConstants.listenMessage,body: {"conversationId":state.chatModel?.id});
  if (res.statusCode == 200) {
    var json= jsonDecode(res.body);
   // debugPrint(json.toString());
    List messagesJson = json["messages"];
    List<MessageModel> messages = messagesJson.map((a)=> MessageModel.fromMap(a)).toList();
    final oldMessages = state.messages ?? [];
final newMessages = messages;

// aynı id'ye sahip mesajları filtrele
final mergedMessages = [
  ...oldMessages,
  ...newMessages.where((m) => !oldMessages.any((old) => old.id == m.id))
];
    ChatState chatState = _chatStateFormatter( json["conversation_state"]);
    state = state.copyWith(chatState: chatState,messages: mergedMessages);
   // Sadece mesajlar varsa debug print yap
   if (state.messages != null && state.messages!.isNotEmpty) {
     debugPrint(state.messages!.last.createdAt.toString());
   }
  }else{
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
    
    // Bedava premium kontrolü
    final canUseTrial = PremiumService.canUseFreeTrial(user);
    log("🎁 [PREMIUM CHECK] Bedava premium kullanılabilir mi: $canUseTrial");
    
    if (canUseTrial) {
      log("✅ [PREMIUM CHECK] Bedava premium süresince - Sınırsız mesaj gönderebilir");
      return true; // Bedava premium süresince sınırsız
    }
    
    // Günlük mesaj limiti kontrolü
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final todayMessageCount = await localService.getDailyMessageCount();
    final limit = PremiumService.getDailyMessageLimit(user);
    
    log("📊 [PREMIUM CHECK] Bugünkü mesaj sayısı: $todayMessageCount");
    log("📊 [PREMIUM CHECK] Günlük mesaj limiti: $limit");
    
    if (limit != null && todayMessageCount >= limit) {
      log("❌ [PREMIUM CHECK] Günlük mesaj limiti aşıldı! ($todayMessageCount >= $limit)");
      // Limit aşıldı, premium ekranına yönlendir
      try {
        log("💳 [PREMIUM CHECK] Premium ekranı açılıyor...");
        await RevenueCatUI.presentPaywall();
        log("✅ [PREMIUM CHECK] Premium ekranı açıldı");
      } catch (e) {
        log("⚠️ [PREMIUM CHECK] Premium ekranı açılamadı: $e");
      }
      return false;
    }
    
    log("✅ [PREMIUM CHECK] Mesaj gönderebilir (${todayMessageCount + 1}/$limit)");
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
    
    // Bedava premium kontrolü
    final canUseTrial = PremiumService.canUseFreeTrial(user);
    log("🎁 [PREMIUM CHECK] Bedava premium kullanılabilir mi: $canUseTrial");
    
    if (canUseTrial) {
      log("✅ [PREMIUM CHECK] Bedava premium süresince - Sınırsız fotoğraf gönderebilir");
      return true;
    }
    
    // Günlük fotoğraf limiti kontrolü
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final todayPhotoCount = await localService.getDailyPhotoCount();
    final limit = PremiumService.getDailyPhotoLimit(user);
    
    log("📸 [PREMIUM CHECK] Bugünkü fotoğraf sayısı: $todayPhotoCount");
    log("📸 [PREMIUM CHECK] Günlük fotoğraf limiti: $limit");
    
    final canSend = PremiumService.canSendPhoto(user, todayPhotoCount);
    
    if (!canSend) {
      log("❌ [PREMIUM CHECK] Günlük fotoğraf limiti aşıldı! ($todayPhotoCount >= $limit)");
      // Limit aşıldı, premium ekranına yönlendir
      try {
        log("💳 [PREMIUM CHECK] Premium ekranı açılıyor...");
        await RevenueCatUI.presentPaywall();
        log("✅ [PREMIUM CHECK] Premium ekranı açıldı");
      } catch (e) {
        log("⚠️ [PREMIUM CHECK] Premium ekranı açılamadı: $e");
      }
      return false;
    }
    
    log("✅ [PREMIUM CHECK] Fotoğraf gönderebilir (${todayPhotoCount + 1}/$limit)");
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
            Translate.translate(TranslateKeys.dailyMessageLimitMessage, context),
            style: GoogleFonts.quicksand(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Onboard ekranına yönlendir
                navigatorKey.currentState?.pushNamedAndRemoveUntil('/onboard', (route) => false);
              },
              child: Text(
                Translate.translate(TranslateKeys.pleaseLoginToContinue, context),
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

  sendMessage()async{
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
        log("❌ [IMAGE] Fotoğraf gönderilemedi - Limit aşıldı veya premium gerekli");
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
          log("❌ [IMAGE] Fotoğraf gönderilemedi - HTTP Status: ${res?.statusCode}");
        } else {
          log("❌ [IMAGE] Fotoğraf gönderilemedi - HTTP Status: ${res?.statusCode}");
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
          "userId": ref?.read(AllControllers.userController)?.id
        }
      );
      
      if (res.statusCode == 200) {
        // Günlük mesaj sayısını artır
        final prefs = await SharedPreferences.getInstance();
        final localService = LocalService(prefs: prefs);
        await localService.incrementDailyMessageCount();
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



ChatState _chatStateFormatter(String state){
  if (state == "bot_typing") {
    return ChatState.botWriting;
  }else if(state == "bot_record_audio"){
   return ChatState.botAudioRecording;
  }else{
    return ChatState.normal;
  }
}

pushFromMessages(ChatModel chatModel,AgentModel selectedAgent)async{
     changeChatModel(chatModel,selectedAgent);
     await  navigatorKey.currentState?.pushNamed("/chatView");
}


  sendAudio(String path)async{
    // Premium ve limit kontrolü
    final canSend = await _canSendMessage();
    if (!canSend) {
      state = state.copyWith(responseWaiting: false);
      return;
    }
  
    HttpService httpService = HttpService(ref: ref);
    state = state.copyWith(responseWaiting: true);
    messageController.clear();
    
    var res = await httpService.postAudioFile(
      path: AppConstants.sendAudioMessage,
      file: File(path),
      conversation: state.chatModel?.id.toString()
    );
    
    if (res != null && res.statusCode == 200) {
      // Günlük mesaj sayısını artır
      final prefs = await SharedPreferences.getInstance();
      final localService = LocalService(prefs: prefs);
      await localService.incrementDailyMessageCount();
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
    }
    
    state = state.copyWith(responseWaiting: false);
  }



audioButton()async{
  if (state.recordState == RecordState.none ) {
   await recordAudio();
  }else if(state.recordState == RecordState.stopped){
   state = state.copyWith(recordState: RecordState.none);
  }else if(state.recordState == RecordState.recording){
  await  stoppingAudio();
  }
}


recordAudio()async{
  if (recorderController.hasPermission) {
   await recorderController.record();
   state = state.copyWith(recordState: RecordState.recording);
  }else{
  await  recorderController.checkPermission();
  }
}

stoppingAudio()async{
  if (recorderController.isRecording) {
  String? path = await recorderController.stop();
  if (path != null) {
    log("Audio recorded. Path: $path");
     sendAudio(path);
  } else {
    
  }
   state = state.copyWith(recordState: RecordState.stopped);
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



 removeImage()  async{
  
   selectedImage = null;
    debugPrint("Clicked remove Image: ${state.image?.path}");
  }



}

class ConversationModel {
  final ChatModel? chatModel;
  final AgentModel? agentModel;
  ConversationModel({
    this.chatModel,
    this.agentModel,
  });

  ConversationModel copyWith({
    ChatModel? chatModel,
    AgentModel? agentModel,
  }) {
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
    this.image
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
    XFile? image,
  }) {
    return ChatScreenViewModel(
      chatModel: chatModel ?? this.chatModel,
      agent: agent ?? this.agent,
      messages: messages ?? this.messages ,
      chatState: chatState ?? ChatState.normal,
      responseWaiting:  responseWaiting ?? this.responseWaiting,
      conversations: conversations ?? this.conversations,
      filteredConversations: filteredConversations ?? this.filteredConversations,
      isSearching: isSearching ?? this.isSearching,
      recordState: recordState ?? this.recordState,
      image: image ?? this.image
    );
  }






}
enum ChatState {
  normal,
  botWriting,
  botAudioRecording
}

enum RecordState{
  recording,
  stopped,
  none,

}

