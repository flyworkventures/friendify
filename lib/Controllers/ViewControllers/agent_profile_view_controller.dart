import 'dart:convert';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';

import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:http/http.dart';
import 'package:friendfy/Services/paywall_presentation.dart';
import 'package:flutter/material.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';

/// Backend `ownerId` doğrulaması genelde JWT içindeki kullanıcı id ile yapılır;
/// [UserModel.id] token yenileme / cache sonrası güncel olmayabiliyor.
Map<String, dynamic>? _decodeJwtPayload(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    var segment = parts[1];
    final rem = segment.length % 4;
    if (rem == 2) {
      segment += '==';
    } else if (rem == 3) {
      segment += '=';
    } else if (rem == 1) {
      return null;
    }
    final decoded = utf8.decode(base64Url.decode(segment));
    final map = jsonDecode(decoded);
    return map is Map<String, dynamic> ? map : null;
  } catch (_) {
    return null;
  }
}

/// update-agent / create-custom-agent gövdesi için ownerId (veya eşdeğer) değeri.
Object? _ownerIdForAuthenticatedRequests(UserModel? user) {
  final claims = _decodeJwtPayload(user?.token);
  if (claims != null) {
    for (final key in const ['userId', 'user_id', 'id']) {
      final v = claims[key];
      if (v == null) continue;
      if (v is int) return v;
      if (v is String && v.isNotEmpty) {
        final n = int.tryParse(v);
        if (n != null) return n;
      }
    }
    final sub = claims['sub'];
    if (sub is int) return sub;
    if (sub is String && sub.isNotEmpty) {
      final n = int.tryParse(sub);
      if (n != null) return n;
    }
  }
  final id = user?.id;
  if (id != null) return id;
  return null;
}

class AgentProfileViewController extends StateNotifier<AgentProfileViewModel> {
  Ref? ref;
  AgentProfileViewController(this.ref) : super(AgentProfileViewModel());

  changeAgentModel(AgentModel agent) {
    debugPrint("Model: ${agent.riveAvatar}");
    state = state.copyWith(agent: agent);
  }

  Future<void> startChat(AgentModel selectedAgent, {bool onboardingFunnel = false}) async {
    await ref
        ?.read(AllControllers.chatViewController.notifier)
        .openChatFromAgent(selectedAgent, onboardingFunnel: onboardingFunnel);
  }

  Future<dynamic> startVoiceCall(AgentModel selectedAgent) {
    return ref
            ?.read(AllControllers.chatViewController.notifier)
            .openVoiceCallFromAgent(selectedAgent) ??
        Future.value(null);
  }

  Future<dynamic> startVideoCall(AgentModel selectedAgent) {
    return ref
            ?.read(AllControllers.chatViewController.notifier)
            .openVideoCallFromAgent(selectedAgent) ??
        Future.value(null);
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

  AgentModel? _findAgentById(List<AgentModel>? list, int id) {
    if (list == null) return null;
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Sistem/katalog karakterinde düzenleme kaydı [get-user-agents] yerine
  /// aynı id ile [get-system-agents] listesinde güncellenmiş halde kalır.
  void _syncDisplayedAgentAfterListRefresh({
    required AgentModel original,
    required bool isOwnAgent,
    required bool isCatalogSystemEdit,
  }) {
    final avc = ref?.read(AllControllers.agentsViewController);
    if (avc == null) return;
    if (isCatalogSystemEdit) {
      final m = _findAgentById(avc.agents, original.id);
      if (m != null) changeAgentModel(m);
    } else if (isOwnAgent) {
      final m = _findAgentById(avc.userAgents, original.id);
      if (m != null) changeAgentModel(m);
    }
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
    final int? authUserId = user?.id;
    final String? userIdStr = authUserId?.toString();
    final Object? ownerBody = _ownerIdForAuthenticatedRequests(user);

    log("🔍 [AGENT EDIT] Karakter düzenleme başladı");
    log("👤 [AGENT EDIT] UserModel.id: $authUserId | ownerId (JWT öncelikli): $ownerBody");

    state = state.copyWith(loadingScreen: true);

    try {
      HttpService httpService = HttpService(ref: ref);
      AgentModel? originalAgent = state.agent;

      if (originalAgent == null) {
        state = state.copyWith(loadingScreen: false);
        return;
      }

      if (ownerBody == null) {
        log("❌ [AGENT EDIT] ownerId çözülemedi (JWT / kullanıcı id yok)");
        state = state.copyWith(loadingScreen: false);
        return;
      }

      // Kontrol: Kullanıcının kendi karakteri mi? (system == 0 ve creatorId eşleşiyor mu?)
      final bool isOwnAgent = originalAgent.system == 0 &&
          (originalAgent.creatorId == userIdStr ||
              originalAgent.creatorId == ownerBody.toString());
      // Katalog (system != 0) düzenlemesi: yeni "kullanıcı karakteri" oluşturma,
      // aynı bot id ile yerinde güncelleme — sadece Arkadaş oluştur akışında create kullanılır.
      final bool isCatalogSystemEdit = !isCreateFlow &&
          !isOwnAgent &&
          originalAgent.system != 0;
      final hasSelectedPhoto =
          selectedPhotoUrl != null && selectedPhotoUrl.trim().isNotEmpty;
      String resolvedPhotoUrl =
          hasSelectedPhoto ? selectedPhotoUrl!.trim() : originalAgent.photoURL;
      if (resolvedPhotoUrl.trim().isEmpty) {
        for (final u in originalAgent.photoURLs) {
          final t = u.trim();
          if (t.isNotEmpty) {
            resolvedPhotoUrl = t;
            break;
          }
        }
      }

      log("🔍 [AGENT EDIT] Agent ID: ${originalAgent.id}");
      log("🔍 [AGENT EDIT] Agent Creator ID: ${originalAgent.creatorId}");
      log("🔍 [AGENT EDIT] Agent System: ${originalAgent.system}");
      log("🔍 [AGENT EDIT] Is Own Agent: $isOwnAgent");
      log("🔍 [AGENT EDIT] Catalog in-place edit: $isCatalogSystemEdit");

      final String interestsJson = jsonEncode(interests);
      final String countryRaw = originalAgent.country.trim();
      final String resolvedCountry =
          countryRaw.isEmpty ? 'TR' : countryRaw;
      final String? resolvedVoiceId = (voiceId != null && voiceId.isNotEmpty)
          ? voiceId
          : originalAgent.voiceId;
      final String resolvedSpeaking =
          (originalAgent.speakingStyle ?? '').toString().trim();

      Map<String, dynamic> editedAgentData = {
        'name': name,
        'character': character,
        'age': age,
        'gender': gender,
        'interests': interestsJson,
        'interestsType': interestsJson,
        'photoURL': resolvedPhotoUrl,
        'characterTags': originalAgent.characterTags,
        'speakingStyle': resolvedSpeaking,
        'voiceId': resolvedVoiceId,
        'country': resolvedCountry,
        'ownerId': ownerBody,
      };
      final riveUrl = originalAgent.riveAvatar?.trim();
      if (riveUrl != null && riveUrl.isNotEmpty) {
        editedAgentData['rive_avatar'] = riveUrl;
      }

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
        // Ücretli abonelik veya deneme: katalog düzenleme ve yeni karakter oluşturma
        final canCreate = PremiumService.hasUnlockedPremiumFeatures(user);
        log("💎 [PREMIUM CHECK] Karakter düzenleme/oluşturma izni: $canCreate");

        if (!canCreate) {
          log(
            "❌ [PREMIUM CHECK] Karakter düzenleme için abonelik veya aktif deneme gerekli",
          );

          state = state.copyWith(loadingScreen: false);

          try {
            log("💳 [PREMIUM CHECK] Premium ekranı açılıyor...");
            await PaywallPresentation.presentFromNavigator();
            log("✅ [PREMIUM CHECK] Premium ekranı açıldı");
          } catch (e) {
            log("⚠️ [PREMIUM CHECK] Premium ekranı açılamadı: $e");
          }

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

        if (isCatalogSystemEdit) {
          log("✅ [AGENT EDIT] Katalog karakteri — yerinde UPDATE (Oluşturduklarım'a eklenmez)");
          editedAgentData['agentId'] = originalAgent.id.toString();
          editedAgentData['userId'] = ownerBody;
          response = await httpService.post(
            path: AppConstants.updateAgent,
            body: editedAgentData,
          );
          if (response.statusCode == 200) {
            log("✅ [AGENT EDIT] Katalog karakteri güncellendi");
          } else {
            log("❌ [AGENT EDIT] Katalog güncelleme başarısız: ${response.body}");
          }
        } else {
          log("✅ [AGENT EDIT] Yeni özel karakter oluşturuluyor (Arkadaş oluştur / kopya)");
          final createBody = Map<String, dynamic>.from(editedAgentData);
          createBody['userId'] = ownerBody;
          // editedAgentData içinde interests + interestsType zaten aynı JSON string (interestsJson).
          // Dizi gönderimi bazı Node/Prisma şemalarında CREATE_AGENT_FAILED üretebiliyor.
          final ct = createBody['characterTags'];
          if (ct != null && ct is! String) {
            try {
              createBody['characterTags'] = jsonEncode(ct);
            } catch (_) {
              createBody['characterTags'] = '';
            }
          }
          response = await httpService.post(
            path: AppConstants.createCustomAgent,
            body: createBody,
          );
          if (response.statusCode == 200) {
            log("✅ [AGENT EDIT] Agent created successfully");
          } else {
            log(
              "❌ [AGENT EDIT] Failed to create custom agent: ${response.body} "
              "(voiceId=${createBody['voiceId']}, interestsCount=${interests.length})",
            );
          }
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

        // Listeleri yenile (katalog güncellemesi get-system-agents'ta görünür)
        await ref
            ?.read(AllControllers.agentsViewController.notifier)
            .getAgents();
        await ref
            ?.read(AllControllers.agentsViewController.notifier)
            .getUserAgents();
        debugPrint("✅ Agents + user agents refreshed");

        _syncDisplayedAgentAfterListRefresh(
          original: originalAgent,
          isOwnAgent: isOwnAgent,
          isCatalogSystemEdit: isCatalogSystemEdit,
        );

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
                  (isOwnAgent || isCatalogSystemEdit)
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
    final int? authUserId = user?.id;
    final agent = state.agent;
    final Object? ownerBody = _ownerIdForAuthenticatedRequests(user);

    if (agent == null || ownerBody == null) {
      return;
    }

    // Kontrol: Kullanıcının kendi karakteri mi?
    final bool isOwnAgent = agent.system == 0 &&
        (agent.creatorId == authUserId?.toString() ||
            agent.creatorId == ownerBody.toString());

    if (!isOwnAgent) {
      log("❌ [AGENT DELETE] Cannot delete - not user's agent");
      return;
    }

    state = state.copyWith(loadingScreen: true);

    try {
      HttpService httpService = HttpService(ref: ref);

      var response = await httpService.post(
        path: AppConstants.deleteAgent,
        body: {'agentId': agent.id.toString(), 'ownerId': ownerBody},
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
