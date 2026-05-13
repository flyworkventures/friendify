import 'dart:convert';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';

import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Models/chat_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:http/http.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';

class AgentProfileViewController extends StateNotifier<AgentProfileViewModel> {
  Ref? ref;
  AgentProfileViewController(this.ref) : super(AgentProfileViewModel());

  changeAgentModel(AgentModel agent) {
    debugPrint("Model: ${agent.toMap().toString()}");
    state = state.copyWith(agent: agent);
  }

  Future<bool> _prepareChatForAgent(AgentModel selectedAgent) async {
    state = state.copyWith(loadingScreen: true);
    HttpService httpService = HttpService(ref: ref);
    var response = await httpService.post(
      path: AppConstants.createChat,
      body: {
        "userId": ref?.read(AllControllers.userController)!.id,
        "botId": selectedAgent.id,
      },
    );

    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      _printConversationState(json["msg"]);
      ChatModel chatModel = ChatModel.fromMap(json["conversationData"]);
      ref
          ?.read(AllControllers.chatViewController.notifier)
          .changeChatModel(chatModel, selectedAgent);
      state = state.copyWith(loadingScreen: false);
      return true;
    } else {
      state = state.copyWith(loadingScreen: false);
      return false;
    }
  }

  Future<void> startChat(AgentModel selectedAgent, {bool onboardingFunnel = false}) async {
    final prepared = await _prepareChatForAgent(selectedAgent);
    if (!prepared) return;
    await navigatorKey.currentState?.pushNamed(
      "/chatView",
      arguments: onboardingFunnel ? {"onboardingFunnel": true} : null,
    );
  }

  Future<void> startVoiceCall(AgentModel selectedAgent) async {
    final prepared = await _prepareChatForAgent(selectedAgent);
    if (!prepared) return;
    await navigatorKey.currentState?.pushNamed("/voiceCallView");
  }

  Future<void> startVideoCall(AgentModel selectedAgent) async {
    final prepared = await _prepareChatForAgent(selectedAgent);
    if (!prepared) return;
    await navigatorKey.currentState?.pushNamed("/videoCallView");
  }

  int _extractSavedAgentId(String responseBody, {required int fallbackAgentId}) {
    try {
      final decoded = jsonDecode(responseBody);
      final id = _readAgentId(decoded);
      return id ?? fallbackAgentId;
    } catch (_) {
      return fallbackAgentId;
    }
  }

  int? _readAgentId(dynamic value) {
    if (value is Map) {
      for (final key in const ['agentId', 'botId', 'id']) {
        final raw = value[key];
        if (raw is int) return raw;
        if (raw is String) return int.tryParse(raw);
      }

      for (final key in const ['agent', 'agentData', 'bot', 'botData', 'data']) {
        final nested = _readAgentId(value[key]);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  _printConversationState(String msg) {
    debugPrint(msg);
    if (msg == "Conversation Created") {
      log("New Coversation Created");
    } else {
      log("Get Coversation Data ");
    }
  }

  Future<void> saveEditedAgent({
    required String name,
    required String character,
    required int age,
    required String gender,
    required List<String> interests,
    String? voiceId,
    String? selectedPhotoUrl,
    bool isCreateFlow = false,
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
      final bool isOwnAgent =
          originalAgent.system == 0 && originalAgent.creatorId == userId;
      final hasSelectedPhoto =
          selectedPhotoUrl != null && selectedPhotoUrl.trim().isNotEmpty;
      final resolvedPhotoUrl =
          hasSelectedPhoto ? selectedPhotoUrl.trim() : originalAgent.photoURL;

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
        'interestsType':
            originalAgent.interestsType, // Keep original interest types
        'photoURL': resolvedPhotoUrl,
        'characterTags': originalAgent.characterTags,
        'speakingStyle': originalAgent.speakingStyle,
        'voiceId': (voiceId != null && voiceId.isNotEmpty)
            ? voiceId
            : originalAgent.voiceId,
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
          // Free trial kullanıcıları da karakter düzenleyemez (paywall tetiklenmeli)
          final canEdit = PremiumService.canEditCharacter(user, 0);

          if (!canEdit) {
            log(
              "❌ [PREMIUM CHECK] Karakter düzenleme/oluşturma için Premium gerekli",
            );

            state = state.copyWith(loadingScreen: false);

            // Premium ekranına yönlendir
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
                  content: Text(
                    Translate.translate(
                      'character_edit_requires_premium',
                      navigatorKey.currentContext!,
                    ),
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }

            return;
          }
        }

        response = await httpService.post(
          path: AppConstants.createCustomAgent,
          body: editedAgentData,
        );

        if (response.statusCode == 200) {
          log("✅ [AGENT EDIT] Agent created successfully");

          // Premium kullanıcılar için sayacı artırmaya gerek yok (sınırsız)
          // Free trial ve normal kullanıcılar zaten paywall ile engellendi
        } else {
          log("❌ [AGENT EDIT] Failed to create custom agent: ${response.body}");
        }
      }

      if (response.statusCode == 200) {
        if (hasSelectedPhoto) {
          final savedAgentId = _extractSavedAgentId(
            response.body,
            fallbackAgentId: originalAgent.id,
          );
          await LocalService.saveSelectedAgentPhoto(
            agentId: savedAgentId,
            photoUrl: resolvedPhotoUrl,
          );
        }

        // Kullanıcının botlarını yeniden çek
        await ref
            ?.read(AllControllers.agentsViewController.notifier)
            .getUserAgents();
        debugPrint("✅ User agents refreshed");

        state = state.copyWith(loadingScreen: false);

        navigatorKey.currentState?.pop();
        if (!isCreateFlow) {
          navigatorKey.currentState?.pop();
        }
      } else {
        log("❌ [AGENT EDIT] Failed: ${response.body}");
        state = state.copyWith(loadingScreen: false);

        // Show error message
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(
                Translate.translate(
                  isOwnAgent
                      ? TranslateKeys.agentUpdateFailed
                      : TranslateKeys.agentCreateFailed,
                  navigatorKey.currentContext!,
                ),
              ),
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
        body: {'agentId': agent.id.toString(), 'ownerId': userId},
      );

      if (response.statusCode == 200) {
        log("✅ [AGENT DELETE] Agent deleted successfully");

        // Kullanıcının botlarını yeniden çek
        await ref
            ?.read(AllControllers.agentsViewController.notifier)
            .getUserAgents();
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
              content: Text(
                Translate.translate(
                  TranslateKeys.agentDeleteFailed,
                  navigatorKey.currentContext!,
                ),
              ),
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
  AgentProfileViewModel({this.agent, this.loadingScreen = false});

  AgentProfileViewModel copyWith({AgentModel? agent, bool? loadingScreen}) {
    return AgentProfileViewModel(
      agent: agent ?? this.agent,
      loadingScreen: loadingScreen ?? false,
    );
  }
}
