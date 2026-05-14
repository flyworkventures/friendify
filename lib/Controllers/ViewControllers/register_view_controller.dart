// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';

import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/Services/notification_service.dart';
import 'package:friendfy/Services/device_trial_eligibility_service.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterViewController extends StateNotifier<RegisterModel> {
  final Ref? ref;

  RegisterViewController(this.ref) : super(RegisterModel());

  PageController pageController = PageController(initialPage: 0);

  TextEditingController usernameController = TextEditingController();
  HttpService httpService = HttpService();
  String? gender;

  List hobbies = [];
  UserModel? user;
  DateTime? birthdate;
  String credential = "google";

  /// Kayıt 4. adım: AI partnerden beklenti (slug, örn. flirting).
  String? aiPartnerExpectation;

  /// Kayıt 5. adım: Tercih edilen zaman (slug, örn. late_night).
  String? aiPreferredTime;

  List<String> imagePaths = [
    "assets/register1.png",
    "assets/register2.png",
    "assets/register3.png",
    "assets/register4.png",
  ];

  /// Provider ömür boyu yaşadığı için; hesap silme / tekrar register’ta bellekte kalan adım ve PageController sıfırlanır.
  void resetRegistrationFlow() {
    pageController.dispose();
    pageController = PageController(initialPage: 0);
    usernameController.clear();
    gender = null;
    hobbies = [];
    user = null;
    birthdate = null;
    aiPartnerExpectation = null;
    aiPreferredTime = null;
    appleUserIdentifier = null;
    appleToken = null;
    state = RegisterModel();
  }

  updateBirthdate(DateTime newBirthdate) {
    birthdate = newBirthdate;
    debugPrint(
      "New birthday: ${birthdate?.day}/${birthdate?.month}/${birthdate?.year}",
    );
  }

  updateCredential(String newCredential) {
    credential = newCredential;
  }

  updateUserModel(UserModel userModel) {
    state = state.copyWith(userModel: userModel);
  }

  updateEmail(String? email) {
    state = state.copyWith(email: email);
  }

  String? appleUserIdentifier;
  String? appleToken; // Apple authorizationCode (token revoke için)

  updateAppleUserIdentifier(String identifier) {
    appleUserIdentifier = identifier;
    debugPrint("✅ Apple UserIdentifier stored: $identifier");
  }

  updateAppleToken(String token) {
    appleToken = token;
    debugPrint("✅ Apple Token stored: $token");
  }

  updateUsername(String username) {
    state = state.copyWith(username: username);
  }

  updateGender(String? newGender) {
    gender = newGender;
    // Null değerini de set edebilmek için direkt yeni model oluştur
    state = RegisterModel(
      userModel: state.userModel,
      email: state.email,
      username: state.username,
      currentIndex: state.currentIndex,
      selectedTags: state.selectedTags,
      gender: newGender,
      aiPartnerExpectation: state.aiPartnerExpectation,
      aiPreferredTime: state.aiPreferredTime,
    );
    debugPrint("Selected gender: $gender");
  }

  updateHobbies(List newHobbies) {
    hobbies = newHobbies;
    state = state.copyWith(selectedTags: List<String>.from(newHobbies));
    debugPrint("Selected hobbies: $hobbies");
  }

  void updateAiPartnerExpectation(String slug) {
    aiPartnerExpectation = slug;
    state = state.copyWith(aiPartnerExpectation: slug);
  }

  void updateAiPreferredTime(String slug) {
    aiPreferredTime = slug;
    state = state.copyWith(aiPreferredTime: slug);
  }

  Future<void> hydrateFromLocalAnswers({
    required String email,
    required String credential,
    String? fallbackUsername,
  }) async {
    resetRegistrationFlow();
    updateEmail(email);
    updateCredential(credential);
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final answers = localService.getOnboardingAnswers() ?? {};
    final storedUsername = (answers["username"] ?? "").toString().trim();
    final finalUsername = storedUsername.isNotEmpty
        ? storedUsername
        : (fallbackUsername ?? "Friendify User");
    usernameController.text = finalUsername;
    updateUsername(finalUsername);

    final rawBirthdate = answers["birthdate"]?.toString();
    if (rawBirthdate != null && rawBirthdate.isNotEmpty) {
      birthdate = DateTime.tryParse(rawBirthdate);
    }
    birthdate ??= DateTime(2000, 1, 1);
    gender = answers["gender"]?.toString();

    final rawHobbies = answers["hobbies"];
    if (rawHobbies is List) {
      hobbies = List<String>.from(rawHobbies.map((e) => e.toString()));
      state = state.copyWith(selectedTags: List<String>.from(hobbies));
    }
    aiPartnerExpectation = answers["aiPartnerExpectation"]?.toString();
    aiPreferredTime = answers["aiPreferredTime"]?.toString();
    state = state.copyWith(
      gender: gender,
      aiPartnerExpectation: aiPartnerExpectation,
      aiPreferredTime: aiPreferredTime,
    );
  }

  Future<void> saveAnswersToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    await localService.saveOnboardingAnswers({
      "username": usernameController.text.trim(),
      "gender": gender,
      "birthdate": birthdate?.toIso8601String(),
      "hobbies": hobbies,
      "aiPartnerExpectation": aiPartnerExpectation,
      "aiPreferredTime": aiPreferredTime,
      "savedAt": DateTime.now().toIso8601String(),
    });
  }

  toggleTag(String tag) {
    List<String> currentTags = List<String>.from(state.selectedTags);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
    } else {
      currentTags.add(tag);
    }
    state = state.copyWith(selectedTags: currentTags);
    hobbies = currentTags;
    debugPrint("Tags updated: $currentTags");
  }

  /// Kayıt API + token + hoş geldin bildirimi + trial + sohbet/agent ön yükleme. Başarılıysa `true`.
  Future<bool> createUser() async {
    try {
      debugPrint("🟢 createUser started with credential: $credential");

      if (credential != "google" &&
          credential != "facebook" &&
          credential != "apple") {
        debugPrint("⚠️ Unsupported credential: $credential");
        return false;
      }

      final userModel = UserModel(
        username: usernameController.text,
        email: state.email!,
        accountCreatedDate: DateTime.now(),
        birthdate: birthdate!,
        memberships: {},
        ownAgents: [],
        verificated: 1,
        credential: credential,
        lastLogins: {},
        counrty: "tr",
        hobbies: hobbies,
        gender: gender,
      );

      debugPrint("🌐 Sending signup request with credential: $credential");

      final userModelMap = userModel.toMap();
      if (aiPartnerExpectation != null && aiPartnerExpectation!.isNotEmpty) {
        userModelMap['aiPartnerExpectation'] = aiPartnerExpectation;
      }
      if (aiPreferredTime != null && aiPreferredTime!.isNotEmpty) {
        userModelMap['aiPreferredTime'] = aiPreferredTime;
      }
      if (credential == "apple" && appleUserIdentifier != null) {
        userModelMap['appleUserIdentifier'] = appleUserIdentifier;
        userModelMap['userIdentifier'] = appleUserIdentifier;
        if (appleToken != null && appleToken!.isNotEmpty) {
          userModelMap['appleToken'] = appleToken;
          userModelMap['authorizationCode'] = appleToken;
          debugPrint(
            "🍎 Adding Apple Token (authorizationCode) to userModel: $appleToken",
          );
        }
        debugPrint(
          "🍎 Adding Apple UserIdentifier to userModel: $appleUserIdentifier",
        );
      }

      final response = await httpService.post(
        path: AppConstants.signupURL,
        body: {"credential": credential, "userModel": userModelMap},
        headers: {"Content-type": "application/json"},
      );

      debugPrint("📡 Signup response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("✅ Signup response: ${response.body}");

        if (json["token"] == null) {
          return false;
        }

        final localService = LocalService(
          prefs: await SharedPreferences.getInstance(),
        );
        await localService.setAuthTokens(
          accessToken: json["token"],
          refreshToken:
              (json["refreshToken"] ??
                      (json["user"] is Map<String, dynamic>
                          ? json["user"]["refreshToken"]
                          : null))
                  ?.toString(),
        );

        UserModel completeUserModel;
        if (json["user"] != null) {
          completeUserModel = UserModel.fromMap(
            Map<String, dynamic>.from(json["user"] as Map),
          );
          debugPrint(
            "✅ UserModel from backend with ID: ${completeUserModel.id}",
          );
        } else {
          // Server user döndürmediyse verifyToken ile user bilgisini çek
          final token = json["token"].toString();
          final refreshToken = (json["refreshToken"] ?? "").toString();
          try {
            final verifyResponse = await httpService.post(
              path: AppConstants.verifyTokenURL,
              body: {"token": token, "refreshToken": refreshToken},
              headers: {
                "x-auth-token": token,
                "x-refresh-token": refreshToken,
                "Content-type": "application/json",
              },
            );
            final verifyJson = jsonDecode(verifyResponse.body);
            if (verifyJson["user"] != null) {
              completeUserModel = UserModel.fromMap(
                Map<String, dynamic>.from(verifyJson["user"] as Map),
              ).copyWith(token: token, refreshToken: refreshToken);
              debugPrint("✅ UserModel from verifyToken with ID: ${completeUserModel.id}");
            } else {
              completeUserModel = userModel.copyWith(token: token);
              debugPrint("⚠️ Using local UserModel (ID may be null)");
            }
          } catch (e) {
            completeUserModel = userModel.copyWith(token: json["token"]);
            debugPrint("⚠️ verifyToken failed, using local UserModel: $e");
          }
        }

        ref
            ?.read(AllControllers.userController.notifier)
            .updateUserModel(completeUserModel);
        debugPrint(
          "✅ UserController updated with user ID: ${completeUserModel.id}",
        );

        await _createFreeTrialForNewUser(completeUserModel, ref);

        await Future.delayed(const Duration(milliseconds: 200));

        debugPrint("🔄 Fetching conversations...");
        await ref
            ?.read(AllControllers.chatViewController.notifier)
            .getConversations();

        debugPrint("🔄 Fetching agents...");
        await ref
            ?.read(AllControllers.agentsViewController.notifier)
            .getAgents();
        await ref
            ?.read(AllControllers.agentsViewController.notifier)
            .getRecentAgents();

        debugPrint("✨ Signup pipeline completed");
        return true;
      }

      if (response.statusCode == 400) {
        final json = jsonDecode(response.body);
        debugPrint("⚠️ Signup failed - User already exists");
        debugPrint("Response: ${response.body}");

        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(
                json["msg"] ??
                    Translate.translate(
                      TranslateKeys.registerEmailAlreadyRegistered,
                      navigatorKey.currentContext!,
                    ),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        await Future.delayed(const Duration(seconds: 2));
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/onboard',
          (route) => false,
        );
        return false;
      }

      debugPrint("❌ Signup failed with status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(
              Translate.translate(
                TranslateKeys.registerGenericError,
                navigatorKey.currentContext!,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint("❌ Error in createUser: $e");
      debugPrint("📍 StackTrace: $stackTrace");
      return false;
    }
  }

  previousPage() {
    if (state.currentIndex > 0) {
      pageController.previousPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.ease,
      );
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    } else {
      // Register kök route olduğunda pop siyah ekrana düşürebilir; güvenli dönüş.
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/onboard',
        (route) => false,
      );
    }
  }

  /// Sonraki adıma geç (0: profil, 1: doğum, 2: ilgi alanları, 3: AI beklenti, 4: zaman).
  void pushBirthdayPage() {
    final i = state.currentIndex;
    if (i == 0) {
      if (usernameController.text.trim().isNotEmpty) {
        updateUsername(usernameController.text);
        pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
        state = state.copyWith(currentIndex: 1);
      }
    } else if (i == 1) {
      if (birthdate != null) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
        state = state.copyWith(currentIndex: 2);
      }
    } else if (i == 2) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
      state = state.copyWith(currentIndex: 3);
    } else if (i == 3) {
      if (aiPartnerExpectation != null && aiPartnerExpectation!.isNotEmpty) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
        state = state.copyWith(currentIndex: 4);
      }
    }
  }

  /// Yeni kullanıcı için free trial oluştur (süre: `PremiumService.freeTrialDays` gün).
  Future<void> _createFreeTrialForNewUser(UserModel user, Ref? ref) async {
    try {
      debugPrint(
        "🎁 [FREE TRIAL] Creating free trial for new user: ${user.email}",
      );
      debugPrint("🎁 [FREE TRIAL] User ID: ${user.id}");

      await DeviceTrialEligibilityService.applyStoredTrialLockToPremiumService();
      if (PremiumService.freeTrialConsumedOnThisDevice) {
        debugPrint(
          "🎁 [FREE TRIAL] Skipped: this device already used the app trial",
        );
        return;
      }

      // User ID kontrolü
      if (user.id == null) {
        debugPrint("❌ [FREE TRIAL] User ID is null, cannot create free trial");
        return;
      }

      final userToken = user.token?.trim() ?? '';
      final deviceFp =
          await DeviceTrialEligibilityService.deviceTrialFingerprint();
      final fpTrim = deviceFp?.trim() ?? '';

      // Yerel deneme + update-premium: token/fp yetersiz | claim 503 (migration) | ağ/parse hatası
      var useLegacyLocalTrial =
          userToken.isEmpty || fpTrim.length < 8;

      if (!useLegacyLocalTrial) {
        try {
          final claimResp = await httpService.post(
            path: AppConstants.claimFreeTrialURL,
            body: {
              'userId': user.id!,
              'deviceTrialFingerprint': fpTrim,
            },
            headers: {
              'x-auth-token': userToken,
              'Content-Type': 'application/json',
            },
          );

          if (claimResp.statusCode == 409) {
            await DeviceTrialEligibilityService.markTrialClaimedForThisDevice();
            debugPrint(
              '🎁 [FREE TRIAL] Skipped: server says device trial not allowed',
            );
            return;
          }

          if (claimResp.statusCode == 200) {
            Map<String, dynamic>? data;
            try {
              final decoded = json.decode(claimResp.body);
              if (decoded is Map<String, dynamic>) {
                data = decoded;
              } else if (decoded is Map) {
                data = Map<String, dynamic>.from(decoded);
              }
            } catch (e) {
              debugPrint(
                '⚠️ [FREE TRIAL] claim 200 gövdesi parse edilemedi: $e',
              );
              return;
            }
            final rawUser = data?['user'];
            if (rawUser is Map) {
              final userMap = Map<String, dynamic>.from(rawUser);
              dynamic membershipsRaw = userMap['memberships'];
              if (membershipsRaw is String) {
                try {
                  membershipsRaw = json.decode(membershipsRaw);
                } catch (_) {}
              }
              final mergedUser = user.copyWith(memberships: membershipsRaw);
              ref?.read(AllControllers.userController.notifier).updateUserModel(
                    mergedUser,
                  );

              final list = PremiumService.parseMemberships(membershipsRaw);
              PremiumModel? trial;
              for (final p in list) {
                if (p.type == PremiumType.freeTrial && p.isActive) {
                  trial = p;
                  break;
                }
              }
              if (trial != null) {
                debugPrint(
                  '⏰ [FREE TRIAL] Scheduling trial ended notification (server claim)...',
                );
                await _scheduleTrialEndedNotification(mergedUser, trial);
              }

              await DeviceTrialEligibilityService.markTrialClaimedForThisDevice();
              debugPrint('✅ [FREE TRIAL] Server claim path completed');
              return;
            }
            debugPrint(
              '⚠️ [FREE TRIAL] claim 200 ama gövdede user yok; yerel deneme verilmiyor',
            );
            return;
          }

          if (claimResp.statusCode == 503) {
            debugPrint(
              '⚠️ [FREE TRIAL] claim-free-trial 503 (migration), yerel deneme yolu',
            );
            useLegacyLocalTrial = true;
          } else {
            debugPrint(
              '🎁 [FREE TRIAL] claim-free-trial ${claimResp.statusCode}; yerel fallback yok',
            );
            return;
          }
        } catch (e) {
          debugPrint(
            '⚠️ [FREE TRIAL] claim-free-trial ağ/hata, yerel deneme yolu: $e',
          );
          useLegacyLocalTrial = true;
        }
      }

      // Free trial oluştur (sunucu claim yok / 503 veya ağ — geriye dönük)
      final freeTrial = PremiumService.createFreeTrial(user);
      debugPrint(
        "✅ [FREE TRIAL] Free trial created: ${freeTrial.startDate} - ${freeTrial.endDate}",
      );
      debugPrint("✅ [FREE TRIAL] Free trial type: ${freeTrial.type}");
      debugPrint("✅ [FREE TRIAL] Free trial isActive: ${freeTrial.isActive}");

      // Free trial'ı user'a ekle
      final updatedMemberships = PremiumService.addPremiumToMemberships(
        user,
        freeTrial,
      );
      debugPrint(
        "✅ [FREE TRIAL] Updated memberships count: ${updatedMemberships.length}",
      );

      // Yerel kullanıcıyı her durumda güncelle (PremiumService parse + karakter oluşturma)
      final userWithTrial = user.copyWith(memberships: updatedMemberships);
      ref?.read(AllControllers.userController.notifier).updateUserModel(
            userWithTrial,
          );

      // Backend'e gönder (opsiyonel - hata olsa bile bildirim gönderilecek)
      try {
        final userToken = user.token ?? "";
        if (userToken.isEmpty) {
          debugPrint(
            "⚠️ [FREE TRIAL] User token is empty, skipping backend update",
          );
        } else {
          final headers = {
            'x-auth-token': userToken,
            'Content-Type': 'application/json',
          };

          final membershipsJson = PremiumService.membershipsToJson(
            updatedMemberships,
          );
          debugPrint("📤 [FREE TRIAL] Sending to backend...");

          final deviceFp =
              await DeviceTrialEligibilityService.deviceTrialFingerprint();
          final response = await httpService.post(
            path: AppConstants.updatePremiumURL,
            body: {
              "userId": user.id!,
              "memberships": membershipsJson,
              if (deviceFp != null && deviceFp.isNotEmpty)
                "deviceTrialFingerprint": deviceFp,
            },
            headers: headers,
          );

          if (response.statusCode == 200) {
            debugPrint("✅ [FREE TRIAL] Free trial saved to backend");
          } else {
            debugPrint(
              "❌ [FREE TRIAL] Failed to save free trial to backend: ${response.statusCode}",
            );
            debugPrint("❌ [FREE TRIAL] Response: ${response.body}");
          }
        }
      } catch (backendError) {
        debugPrint(
          "❌ [FREE TRIAL] Backend error (but continuing with notifications): $backendError",
        );
      }

      debugPrint("⏰ [FREE TRIAL] Scheduling trial ended notification...");
      await _scheduleTrialEndedNotification(user, freeTrial);

      await DeviceTrialEligibilityService.markTrialClaimedForThisDevice();

      debugPrint("✅ [FREE TRIAL] Free trial process completed");
    } catch (e, stackTrace) {
      debugPrint("❌ [FREE TRIAL] Error creating free trial: $e");
      debugPrint("❌ [FREE TRIAL] StackTrace: $stackTrace");
    }
  }

  /// Free trial bitiş bildirimi planla
  Future<void> _scheduleTrialEndedNotification(
    UserModel user,
    dynamic freeTrial,
  ) async {
    try {
      debugPrint(
        "⏰ Scheduling trial ended notification for: ${freeTrial.endDate}",
      );

      if (freeTrial.endDate == null) {
        debugPrint("⚠️ Trial end date is null, cannot schedule notification");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('current_locale') ?? 'tr';

      final d = PremiumService.freeTrialDays;
      String title, body;
      switch (langCode) {
        case 'en':
          title = 'Free Trial Ended ⏰';
          body =
              'Your $d-day free trial has ended. Upgrade to Premium to continue enjoying unlimited features!';
          break;
        case 'de':
          title = 'Kostenlose Testversion beendet ⏰';
          body =
              'Ihre $d-tägige kostenlose Testversion ist abgelaufen. Upgraden Sie auf Premium, um weiterhin unbegrenzte Funktionen zu genießen!';
          break;
        default: // tr
          title = 'Ücretsiz Deneme Bitti ⏰';
          body =
              '$d günlük ücretsiz denemeniz sona erdi. Sınırsız özelliklerden yararlanmaya devam etmek için Premium\'a yükseltin!';
      }

      // Trial bitiş zamanında bildirim gönder
      await NotificationService.scheduleSystemNotification(
        title: title,
        body: body,
        scheduledDate: freeTrial.endDate!,
        payload: 'trial_ended',
        notificationId: user.id, // User ID'yi notification ID olarak kullan
      );

      debugPrint(
        "✅ Trial ended notification scheduled for: ${freeTrial.endDate}",
      );
    } catch (e) {
      debugPrint("❌ Error scheduling trial ended notification: $e");
    }
  }
}

class RegisterModel {
  UserModel? userModel;
  String? email;
  String? username;
  int currentIndex;
  List<String> selectedTags;
  String? gender;
  String? aiPartnerExpectation;
  String? aiPreferredTime;
  RegisterModel({
    this.userModel,
    this.email,
    this.username,
    this.currentIndex = 0,
    this.selectedTags = const [],
    this.gender,
    this.aiPartnerExpectation,
    this.aiPreferredTime,
  });

  RegisterModel copyWith({
    UserModel? userModel,
    String? email,
    String? username,
    int? currentIndex,
    List<String>? selectedTags,
    String? gender,
    String? aiPartnerExpectation,
    String? aiPreferredTime,
  }) {
    return RegisterModel(
      userModel: userModel ?? this.userModel,
      email: email ?? this.email,
      username: username ?? this.username,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedTags: selectedTags ?? this.selectedTags,
      gender: gender ?? this.gender,
      aiPartnerExpectation: aiPartnerExpectation ?? this.aiPartnerExpectation,
      aiPreferredTime: aiPreferredTime ?? this.aiPreferredTime,
    );
  }
}
