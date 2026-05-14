// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:friendfy/Repository/auth_repository.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardViewController extends StateNotifier<OnboardViewModel> {
  final Ref ref;

  OnboardViewController(this.ref)
    : super(OnboardViewModel(state: OnboardViewState.normal));

  AuthRepository authRepository = AuthRepository();
  HttpService httpService = HttpService();

  Future<void> _handlePostAuthActionOrHome() async {
    final localService = LocalService(
      prefs: await SharedPreferences.getInstance(),
    );
    final action = localService.getPostAuthAction();
    await localService.clearPostAuthAction();
    await localService.setOnboardingFunnelActive(false);

    if (action == "go_premium") {
      try {
        await RevenueCatUI.presentPaywall(displayCloseButton: true);
      } catch (e) {
        debugPrint("⚠️ Paywall could not be shown: $e");
      }
    }
    await navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/bottomNavbar',
      (route) => false,
    );
  }

  Future<void> _navigateToRegisterFlow() async {
    // createUser sadece token döndürüyor, user ID yok.
    // verifyToken ile tam user model'i (ID dahil) çekelim.
    final prefs = await SharedPreferences.getInstance();
    final localService = LocalService(prefs: prefs);
    final token = await localService.getToken();
    final refreshToken = await localService.getRefreshToken();

    if (token != null && token.isNotEmpty) {
      final httpService = HttpService(ref: ref);
      try {
        final response = await httpService.post(
          path: AppConstants.verifyTokenURL,
          body: {"token": token, "refreshToken": refreshToken ?? ""},
          headers: {
            "x-auth-token": token,
            "x-refresh-token": refreshToken ?? "",
            "Content-type": "application/json",
          },
        );
        final json = jsonDecode(response.body);
        if (json["msg"] == "Valid Token" || json["code"] == "TOKEN_RENEWED") {
          UserModel userModel = UserModel.fromMap(json["user"]);
          userModel = userModel.copyWith(token: token);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            userModel = userModel.copyWith(refreshToken: refreshToken);
          }
          ref.read(AllControllers.userController.notifier).updateUserModel(userModel);
          debugPrint("✅ [RegisterFlow] User model refreshed with ID: ${userModel.id}");
        }
      } catch (e) {
        debugPrint("⚠️ [RegisterFlow] verifyToken error: $e");
      }
    }

    await ref
        .read(AllControllers.chatViewController.notifier)
        .getConversations();
    await ref
        .read(AllControllers.agentsViewController.notifier)
        .getAgents();
    await ref
        .read(AllControllers.agentsViewController.notifier)
        .getRecentAgents();

    // Giriş ekranından Google/Facebook/Apple ile yapılan ilk kayıt: kullanıcı
    // onboarding cevaplarını zaten verdi; demo sohbet yerine doğrudan ana sayfa.
    // (Register UI → AccountCreated → /onboardingDemoChatView ayrı akıştır.)
    debugPrint(
      "✅ [RegisterFlow] Sosyal ile createUser tamamlandı – ana sayfaya yönlendiriliyor",
    );
    await _handlePostAuthActionOrHome();
  }

  googleAuth() async {
    try {
      debugPrint("🔵 [Google Auth] Starting Google authentication flow...");
      LocalService localService = LocalService(
        prefs: await SharedPreferences.getInstance(),
      );

      debugPrint("🔵 [Google Auth] Calling authRepository.googleSignIn()...");
      GoogleSignInAccount? googleSignInAccount = await authRepository
          .googleSignIn();

      if (googleSignInAccount != null) {
        debugPrint("✅ [Google Auth] Google Sign-In account received");
        debugPrint("✅ [Google Auth] Email: ${googleSignInAccount.email}");
        debugPrint(
          "✅ [Google Auth] Display Name: ${googleSignInAccount.displayName}",
        );
        debugPrint("✅ [Google Auth] ID: ${googleSignInAccount.id}");

        debugPrint("🌐 [Google Auth] Checking email on server...");
        debugPrint("🌐 [Google Auth] Endpoint: ${AppConstants.checkMailURL}");
        debugPrint(
          "🌐 [Google Auth] Email to check: ${googleSignInAccount.email}",
        );

        Response response = await httpService.post(
          path: AppConstants.checkMailURL,
          body: {"email": googleSignInAccount.email},
          headers: {"Content-type": "application/json"},
        );

        debugPrint(
          "📡 [Google Auth] Server response status: ${response.statusCode}",
        );
        debugPrint("📡 [Google Auth] Server response body: ${response.body}");

        if (response.statusCode == 200) {
          debugPrint("✨ [Google Auth] New user detected (status 200)");

          final prefs = await SharedPreferences.getInstance();
          final localAnswers = LocalService(prefs: prefs).getOnboardingAnswers();
          final hasLocalAnswers = localAnswers != null && localAnswers.isNotEmpty;

          if (!hasLocalAnswers) {
            debugPrint("📝 [Google Auth] Onboarding cevapları yok – register akışına yönlendiriliyor");
            await localService.saveOnboardingPendingAuth({
              "email": googleSignInAccount.email,
              "credential": "google",
              "fallbackUsername": googleSignInAccount.displayName ?? "",
            });
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/register',
              (route) => false,
            );
            return;
          }

          final registerNotifier = ref.read(
            AllControllers.registerViewController.notifier,
          );
          await registerNotifier.hydrateFromLocalAnswers(
            email: googleSignInAccount.email,
            credential: "google",
            fallbackUsername: googleSignInAccount.displayName,
          );
          final created = await registerNotifier.createUser();
          if (!created) return;
          await _navigateToRegisterFlow();
        } else {
          debugPrint(
            "✨ [Google Auth] Existing user detected (status ${response.statusCode})",
          );
          debugPrint("✨ [Google Auth] Logging in existing user...");

          var json = jsonDecode(response.body);
          log("📦 [Google Auth] UserModel data: ${json["model"][0]}");

          UserModel userModel = UserModel.fromMap(json["model"][0]);
          debugPrint("✅ [Google Auth] UserModel created");
          debugPrint("✅ [Google Auth] User ID: ${userModel.id}");
          debugPrint("✅ [Google Auth] User Email: ${userModel.email}");

          await localService.setAuthTokens(
            accessToken: userModel.token!,
            refreshToken: userModel.refreshToken,
          );
          debugPrint("✅ [Google Auth] Token saved to local storage");

          ref
              .read(AllControllers.userController.notifier)
              .updateUserModel(userModel);
          debugPrint(
            "✅ [Google Auth] UserController updated with user ID: ${userModel.id}",
          );

          // State güncellemesini bekle
          await Future.delayed(Duration(milliseconds: 200));

          debugPrint("🔄 [Google Auth] Fetching user data...");
          await ref
              .read(AllControllers.chatViewController.notifier)
              .getConversations();
          debugPrint("✅ [Google Auth] Conversations fetched");

          await ref
              .read(AllControllers.agentsViewController.notifier)
              .getAgents();
          debugPrint("✅ [Google Auth] Agents fetched");

          await ref
              .read(AllControllers.agentsViewController.notifier)
              .getRecentAgents();
          debugPrint("✅ [Google Auth] Recent agents fetched");

          debugPrint("✨ [Google Auth] All data fetched, navigating to home");
          await _handlePostAuthActionOrHome();
        }
      } else {
        debugPrint("⚠️ [Google Auth] Google Sign-In account is null");
        debugPrint("⚠️ [Google Auth] User may have cancelled the sign-in");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [Google Auth] Error in googleAuth method");
      debugPrint("❌ [Google Auth] Error Type: ${e.runtimeType}");
      debugPrint("❌ [Google Auth] Error: $e");
      debugPrint("📍 [Google Auth] StackTrace: $stackTrace");
      log("❌ [Google Auth] Error in googleAuth: $e");
      log("📍 [Google Auth] StackTrace: $stackTrace");
    }
  }

  facebookAuth() async {
    try {
      debugPrint("🟢 facebookAuth started");
      LocalService localService = LocalService(
        prefs: await SharedPreferences.getInstance(),
      );

      debugPrint("🟢 Calling authRepository.facebookSignIn()");
      Map<String, dynamic>? facebookData = await authRepository
          .facebookSignIn();

      if (facebookData != null) {
        debugPrint("✅ Facebook Account not null");
        debugPrint("📦 Facebook data: $facebookData");

        final userData = facebookData['userData'];
        final String email = userData['email'] ?? '';
        final String name = userData['name'] ?? '';

        debugPrint("📧 Email: $email, Name: $name");

        if (email.isEmpty) {
          debugPrint("❌ Email not provided by Facebook");
          return;
        }

        debugPrint("🌐 Checking email on server...");
        Response response = await httpService.post(
          path: AppConstants.checkMailURL,
          body: {"email": email},
          headers: {"Content-type": "application/json"},
        );

        debugPrint("📡 Server response: ${response.statusCode}");

        if (response.statusCode == 200) {
          debugPrint("✨ Facebook Account 200 - New user creating account");

          final fbPrefs = await SharedPreferences.getInstance();
          final fbLocalAnswers = LocalService(prefs: fbPrefs).getOnboardingAnswers();
          final fbHasLocalAnswers = fbLocalAnswers != null && fbLocalAnswers.isNotEmpty;

          if (!fbHasLocalAnswers) {
            debugPrint("📝 [Facebook Auth] Onboarding cevapları yok – register akışına yönlendiriliyor");
            await localService.saveOnboardingPendingAuth({
              "email": email,
              "credential": "facebook",
              "fallbackUsername": name,
            });
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/register',
              (route) => false,
            );
            return;
          }

          final registerNotifier = ref.read(
            AllControllers.registerViewController.notifier,
          );
          await registerNotifier.hydrateFromLocalAnswers(
            email: email,
            credential: "facebook",
            fallbackUsername: name,
          );
          final created = await registerNotifier.createUser();
          if (!created) return;
          await _navigateToRegisterFlow();
        } else {
          debugPrint("✨ Facebook Account exists, logging in");
          var json = jsonDecode(response.body);
          log("Usermodel: ${json["model"][0]}");
          UserModel userModel = UserModel.fromMap(json["model"][0]);

          await localService.setAuthTokens(
            accessToken: userModel.token!,
            refreshToken: userModel.refreshToken,
          );
          ref
              .read(AllControllers.userController.notifier)
              .updateUserModel(userModel);
          debugPrint("✅ UserController updated with user ID: ${userModel.id}");

          // State güncellemesini bekle
          await Future.delayed(Duration(milliseconds: 200));

          debugPrint("🔄 Fetching user data...");
          await ref
              .read(AllControllers.chatViewController.notifier)
              .getConversations();
          await ref
              .read(AllControllers.agentsViewController.notifier)
              .getAgents();
          await ref
              .read(AllControllers.agentsViewController.notifier)
              .getRecentAgents();

          debugPrint("✨ All data fetched, navigating to home");
          await _handlePostAuthActionOrHome();
        }
      } else {
        debugPrint("⚠️ Facebook login cancelled or failed");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in facebookAuth: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

  appleAuth() async {
    try {
      debugPrint("🍎 appleAuth started");
      LocalService localService = LocalService(
        prefs: await SharedPreferences.getInstance(),
      );

      debugPrint("🍎 Calling authRepository.appleSignIn()");
      Map<String, dynamic>? appleData = await authRepository.appleSignIn();

      if (appleData != null) {
        debugPrint("✅ Apple Account not null");
        debugPrint("📦 Apple data: $appleData");

        final String? email = appleData['email'];
        final String? fullName = appleData['fullName'];
        final String userIdentifier = appleData['userIdentifier'];
        final String? authorizationCode =
            appleData['authorizationCode']; // Apple token (revoke için)

        debugPrint("📧 Email: $email, Name: $fullName, ID: $userIdentifier");

        // Apple için userIdentifier kontrolü (Apple'ın benzersiz kullanıcı ID'si)
        if (userIdentifier.isEmpty) {
          debugPrint("❌ No userIdentifier provided by Apple");
          return;
        }

        debugPrint("🌐 Checking Apple user with identifier on server...");
        Response response = await httpService.post(
          path: AppConstants.checkMailURL,
          body: {"appleUserIdentifier": userIdentifier},
          headers: {"Content-type": "application/json"},
        );

        debugPrint("📡 Server response: ${response.statusCode}");

        if (response.statusCode == 200) {
          debugPrint("✨ Apple Account 200 - New user creating account");

          final applePrefs = await SharedPreferences.getInstance();
          final appleLocalAnswers = LocalService(prefs: applePrefs).getOnboardingAnswers();
          final appleHasLocalAnswers = appleLocalAnswers != null && appleLocalAnswers.isNotEmpty;

          if (!appleHasLocalAnswers) {
            debugPrint("📝 [Apple Auth] Onboarding cevapları yok – register akışına yönlendiriliyor");
            final resolvedEmail =
                email ?? "$userIdentifier@privaterelay.appleid.com";
            await localService.saveOnboardingPendingAuth({
              "email": resolvedEmail,
              "credential": "apple",
              "fallbackUsername": fullName ?? "",
              "appleUserIdentifier": userIdentifier,
              "appleToken": authorizationCode ?? "",
            });
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/register',
              (route) => false,
            );
            return;
          }

          final registerController = ref.read(
            AllControllers.registerViewController.notifier,
          );
          final resolvedEmail =
              email ?? "$userIdentifier@privaterelay.appleid.com";
          await registerController.hydrateFromLocalAnswers(
            email: resolvedEmail,
            credential: "apple",
            fallbackUsername: fullName,
          );

          registerController.updateAppleUserIdentifier(userIdentifier);
          if (authorizationCode != null && authorizationCode.isNotEmpty) {
            registerController.updateAppleToken(authorizationCode);
            debugPrint(
              "🍎 Apple Token (authorizationCode) stored for account deletion: $authorizationCode",
            );
          }
          debugPrint(
            "🍎 Apple UserIdentifier stored for registration: $userIdentifier",
          );

          final created = await registerController.createUser();
          if (!created) return;
          await _navigateToRegisterFlow();
        } else {
          debugPrint("✨ Apple Account exists, logging in");
          var json = jsonDecode(response.body);
          log("Usermodel: ${json["model"][0]}");
          UserModel userModel = UserModel.fromMap(json["model"][0]);

          await localService.setAuthTokens(
            accessToken: userModel.token!,
            refreshToken: userModel.refreshToken,
          );
          ref
              .read(AllControllers.userController.notifier)
              .updateUserModel(userModel);
          debugPrint("✅ UserController updated with user ID: ${userModel.id}");

          // State güncellemesini bekle
          await Future.delayed(Duration(milliseconds: 200));

          debugPrint("🔄 Fetching user data...");
          await ref
              .read(AllControllers.chatViewController.notifier)
              .getConversations();
          await ref
              .read(AllControllers.agentsViewController.notifier)
              .getAgents();
          await ref
              .read(AllControllers.agentsViewController.notifier)
              .getRecentAgents();

          debugPrint("✨ All data fetched, navigating to home");
          await _handlePostAuthActionOrHome();
        }
      } else {
        debugPrint("⚠️ Apple login cancelled or failed");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in appleAuth: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

  Future<bool> guestLogin({bool navigateToHome = true}) async {
    try {
      debugPrint("👤 guestLogin started");
      LocalService localService = LocalService(
        prefs: await SharedPreferences.getInstance(),
      );

      // Device ID al veya oluştur
      String deviceId = await localService.getOrCreateGuestDeviceId();
      debugPrint("📱 Device ID: $deviceId");

      // Guest login endpoint'ine istek gönder
      Response response = await httpService.post(
        path: AppConstants.guestLoginURL,
        body: {"deviceId": deviceId},
        headers: {"Content-type": "application/json"},
      );

      debugPrint("📡 Server response: ${response.statusCode}");

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        debugPrint("✅ Guest login successful");

        UserModel userModel = UserModel.fromMap(json["user"]);

        await localService.setAuthTokens(
          accessToken: userModel.token!,
          refreshToken: userModel.refreshToken,
        );
        ref
            .read(AllControllers.userController.notifier)
            .updateUserModel(userModel);
        debugPrint(
          "✅ UserController updated with guest user ID: ${userModel.id}",
        );

        // State güncellemesini bekle
        await Future.delayed(Duration(milliseconds: 200));

        debugPrint("🔄 Fetching user data...");
        await ref
            .read(AllControllers.chatViewController.notifier)
            .getConversations();
        await ref
            .read(AllControllers.agentsViewController.notifier)
            .getAgents();
        await ref
            .read(AllControllers.agentsViewController.notifier)
            .getRecentAgents();

        if (navigateToHome) {
          debugPrint("✨ All data fetched, navigating to home");
          await _handlePostAuthActionOrHome();
        }
        return true;
      } else {
        debugPrint("❌ Guest login failed: ${response.statusCode}");
        var errorJson = jsonDecode(response.body);
        debugPrint("❌ Error: ${errorJson['msg']}");
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in guestLogin: $e");
      debugPrint("📍 StackTrace: $stackTrace");
      return false;
    }
  }
}

class OnboardViewModel {
  final OnboardViewState state;
  OnboardViewModel({required this.state});

  OnboardViewModel copyWith({OnboardViewState? state}) {
    return OnboardViewModel(state: state ?? this.state);
  }
}

enum OnboardViewState { loading, normal }
