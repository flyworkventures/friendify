
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';

import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Models/chat_model.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter/material.dart';

class AgentProfileViewController extends StateNotifier<AgentProfileViewModel>{
  Ref? ref;
  AgentProfileViewController(this.ref) : super(AgentProfileViewModel());
  



  

  changeAgentModel(AgentModel agent){
    debugPrint("Model: ${agent.toMap().toString()}");
    state = state.copyWith(agent: agent);
  }

  startChat(AgentModel selectedAgent)async{
    state = state.copyWith(loadingScreen: true);
      HttpService httpService = HttpService(ref: ref);
    var response = await httpService.post(
      path: AppConstants.createChat,
      body: {"userId": ref?.read(AllControllers.userController)!.id,"botId": selectedAgent.id}
      );

      if (response.statusCode == 200) {
       var json = jsonDecode(response.body);
       _printConversationState(json["msg"]);
       ChatModel chatModel = ChatModel.fromMap(json["conversationData"]);
       ref?.read(AllControllers.chatViewController.notifier).changeChatModel(chatModel,selectedAgent);
        state = state.copyWith(loadingScreen: false);
     await  navigatorKey.currentState?.pushNamed("/chatView");
      } else {
         state = state.copyWith(loadingScreen: false);
      }
  }



  _printConversationState(String msg){
    debugPrint(msg);
    if (msg== "Conversation Created") {
      log("New Coversation Created");
    }else{
      log("Get Coversation Data ");
    }
  }

  Future<void> saveEditedAgent({
    required String name,
    required String character,
    required int age,
    required String gender,
    required List<String> interests,
  }) async {
    final user = ref?.read(AllControllers.userController);
    final userId = user?.id?.toString();
    
    log("🔍 [AGENT EDIT] Karakter düzenleme başladı");
    log("👤 [AGENT EDIT] User ID: $userId");
    
    state = state.copyWith(loadingScreen: true);
    
    try {
      HttpService httpService = HttpService(ref: ref);
      AgentModel? originalAgent = state.agent;
      
      if (originalAgent == null) {
        state = state.copyWith(loadingScreen: false);
        return;
      }

      // Kontrol: Kullanıcının kendi karakteri mi? (system == 0 ve creatorId eşleşiyor mu?)
      final bool isOwnAgent = originalAgent.system == 0 && 
                             originalAgent.creatorId == userId;
      
      log("🔍 [AGENT EDIT] Agent ID: ${originalAgent.id}");
      log("🔍 [AGENT EDIT] Agent Creator ID: ${originalAgent.creatorId}");
      log("🔍 [AGENT EDIT] Agent System: ${originalAgent.system}");
      log("🔍 [AGENT EDIT] Is Own Agent: $isOwnAgent");

      // Prepare the edited agent data
      Map<String, dynamic> editedAgentData = {
        'name': name,
        'character': character,
        'age': age,
        'gender': gender,
        'interests': jsonEncode(interests),
        'interestsType': originalAgent.interestsType, // Keep original interest types
        'photoURL': originalAgent.photoURL,
        'characterTags': originalAgent.characterTags,
        'speakingStyle': originalAgent.speakingStyle,
        'voiceId': originalAgent.voiceId,
        'country': originalAgent.country,
        'ownerId': userId,
      };

      Response response;
      
      if (isOwnAgent) {
        // Kullanıcının kendi karakteri → UPDATE
        log("✅ [AGENT EDIT] Kullanıcının kendi karakteri - UPDATE yapılıyor");
        editedAgentData['agentId'] = originalAgent.id.toString();
        
        response = await httpService.post(
          path: AppConstants.updateAgent,
          body: editedAgentData,
        );
        
        if (response.statusCode == 200) {
          log("✅ [AGENT EDIT] Agent updated successfully");
        } else {
          log("❌ [AGENT EDIT] Failed to update agent: ${response.body}");
        }
      } else {
        // Sistem karakteri veya başkasının karakteri → CREATE (yeni karakter oluştur)
        log("✅ [AGENT EDIT] Sistem karakteri - YENİ karakter oluşturuluyor");
        
        // Premium kontrolü (sadece yeni karakter oluştururken)
        final isPremium = PremiumService.isPremiumActive(user);
        log("💎 [PREMIUM CHECK] Premium aktif mi: $isPremium");
        
        if (!isPremium) {
          final canUseTrial = PremiumService.canUseFreeTrial(user);
          log("🎁 [PREMIUM CHECK] Bedava premium kullanılabilir mi: $canUseTrial");
          
          if (!canUseTrial) {
            final prefs = await SharedPreferences.getInstance();
            final localService = LocalService(prefs: prefs);
            final currentEditCount = await localService.getCharacterEditCount();
            final limit = PremiumService.getCharacterEditLimit(user);
            
            log("👤 [PREMIUM CHECK] Mevcut düzenlenen karakter sayısı: $currentEditCount");
            log("👤 [PREMIUM CHECK] Karakter düzenleme limiti: $limit");
            
            final canEdit = PremiumService.canEditCharacter(user, currentEditCount);
            
            if (!canEdit) {
              log("❌ [PREMIUM CHECK] Karakter düzenleme limiti aşıldı! ($currentEditCount >= $limit)");
              
              state = state.copyWith(loadingScreen: false);
              
              // Limit aşıldı, premium ekranına yönlendir
              try {
                log("💳 [PREMIUM CHECK] Premium ekranı açılıyor...");
                await RevenueCatUI.presentPaywall();
                log("✅ [PREMIUM CHECK] Premium ekranı açıldı");
              } catch (e) {
                log("⚠️ [PREMIUM CHECK] Premium ekranı açılamadı: $e");
              }
              
              // Show error message
              if (navigatorKey.currentContext != null) {
                ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                  SnackBar(
                    content: Text('You have reached the character edit limit. Upgrade to Premium for unlimited edits.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              
              return;
            }
          }
        }
        
        response = await httpService.post(
          path: AppConstants.createCustomAgent,
          body: editedAgentData,
        );
        
        if (response.statusCode == 200) {
          log("✅ [AGENT EDIT] Agent created successfully");
          
          // Premium değilse karakter düzenleme sayacını artır (sadece yeni oluştururken)
          if (!isPremium && !PremiumService.canUseFreeTrial(user)) {
            final prefs = await SharedPreferences.getInstance();
            final localService = LocalService(prefs: prefs);
            await localService.incrementCharacterEditCount();
            final newCount = await localService.getCharacterEditCount();
            log("📊 [PREMIUM CHECK] Karakter düzenleme sayacı artırıldı: $newCount");
          }
        } else {
          log("❌ [AGENT EDIT] Failed to create custom agent: ${response.body}");
        }
      }

      if (response.statusCode == 200) {
        // Kullanıcının botlarını yeniden çek
        await ref?.read(AllControllers.agentsViewController.notifier).getUserAgents();
        debugPrint("✅ User agents refreshed");
        
        state = state.copyWith(loadingScreen: false);
        
        // Show success message and navigate back
        navigatorKey.currentState?.pop();
        navigatorKey.currentState?.pop();
      } else {
        log("❌ [AGENT EDIT] Failed: ${response.body}");
        state = state.copyWith(loadingScreen: false);
        
        // Show error message
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(isOwnAgent ? 'Failed to update agent' : 'Failed to create agent'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      log("❌ [AGENT EDIT] Error: $e");
      state = state.copyWith(loadingScreen: false);
    }
  }

  Future<void> deleteAgent() async {
    final user = ref?.read(AllControllers.userController);
    final userId = user?.id?.toString();
    final agent = state.agent;
    
    if (agent == null || userId == null) {
      return;
    }
    
    // Kontrol: Kullanıcının kendi karakteri mi?
    final bool isOwnAgent = agent.system == 0 && agent.creatorId == userId;
    
    if (!isOwnAgent) {
      log("❌ [AGENT DELETE] Cannot delete - not user's agent");
      return;
    }
    
    state = state.copyWith(loadingScreen: true);
    
    try {
      HttpService httpService = HttpService(ref: ref);
      
      var response = await httpService.post(
        path: AppConstants.deleteAgent,
        body: {
          'agentId': agent.id.toString(),
          'ownerId': userId,
        },
      );
      
      if (response.statusCode == 200) {
        log("✅ [AGENT DELETE] Agent deleted successfully");
        
        // Kullanıcının botlarını yeniden çek
        await ref?.read(AllControllers.agentsViewController.notifier).getUserAgents();
        debugPrint("✅ User agents refreshed after deletion");
        
        state = state.copyWith(loadingScreen: false);
        
        // Navigate back
        navigatorKey.currentState?.pop();
      } else {
        log("❌ [AGENT DELETE] Failed: ${response.body}");
        state = state.copyWith(loadingScreen: false);
        
        // Show error message
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text('Failed to delete agent'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      log("❌ [AGENT DELETE] Error: $e");
      state = state.copyWith(loadingScreen: false);
    }
  }
}

class AgentProfileViewModel {
  final AgentModel? agent;
  final bool loadingScreen;
  AgentProfileViewModel({
    this.agent,
    this.loadingScreen = false
  });
  

  AgentProfileViewModel copyWith({
    AgentModel? agent,
    bool? loadingScreen
  }) {
    return AgentProfileViewModel(
      agent: agent ?? this.agent,
      loadingScreen:  loadingScreen ?? false
    );
  }

}
