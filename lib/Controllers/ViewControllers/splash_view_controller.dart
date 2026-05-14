import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashViewController extends StateNotifier<void> {
  SplashViewState pageState = SplashViewState.initial;
  final Ref ref;

  SplashViewController(this.ref) : super(null);

  /// Splash ekranının en az [minVisible] süre görünmesini sağlar.
  Future<void> _ensureMinimumSplashVisible(
    DateTime startedAt, {
    Duration minVisible = const Duration(seconds: 3),
  }) async {
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minVisible) {
      await Future<void>.delayed(minVisible - elapsed);
    }
  }

  init() async {
    final splashStartedAt = DateTime.now();

    // Önce versiyon kontrolü yap
    final needsUpdate = await checkAppVersion();
    if (needsUpdate) {
      // Güncelleme gerekli, dialog göster ve çık
      return;
    }

    AppConfigState appState = await getConfig();

    if (appState == AppConfigState.normal) {
      bool? firstOpen = await getFirstOpen();
      if (firstOpen == true || firstOpen == null) {
        changeFirstOpen();
        await _ensureMinimumSplashVisible(splashStartedAt);
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/onboard',
          (a) => false,
        );
      } else {
        // localden jwt Tokeni getireceğiz
        LocalService localService = LocalService(
          prefs: await SharedPreferences.getInstance(),
        );
        HttpService httpService = HttpService(ref: ref);
        String? token = await localService.getToken();
        String? refreshToken = await localService.getRefreshToken();

        if (token != null) {
          debugPrint("Token null değil");
          try {
            var response = await httpService.post(
              path: AppConstants.verifyTokenURL,
              body: {"token": token, "refreshToken": refreshToken ?? ""},
              headers: {
                "x-auth-token": token,
                "x-refresh-token": refreshToken ?? "",
                "Content-type": "application/json",
              },
            );
            var json = jsonDecode(response.body);
            debugPrint("JSON: $json");
            if (json["code"] == "TOKEN_RENEWED" && json["token"] != null) {
              token = json["token"].toString();
              await localService.setAuthTokens(
                accessToken: token,
                refreshToken: json["refreshToken"]?.toString(),
              );
            }

            if (json["msg"] == "Valid Token" || json["code"] == "TOKEN_RENEWED") {
              UserModel userModel = UserModel.fromMap(json["user"]);
              if (token.isNotEmpty) {
                userModel = userModel.copyWith(token: token);
              }
              if ((userModel.refreshToken == null ||
                      userModel.refreshToken!.isEmpty) &&
                  refreshToken != null &&
                  refreshToken.isNotEmpty) {
                userModel = userModel.copyWith(refreshToken: refreshToken);
              }
              if ((refreshToken == null || refreshToken.isEmpty) &&
                  userModel.refreshToken != null &&
                  userModel.refreshToken!.isNotEmpty) {
                await localService.setRefreshToken(userModel.refreshToken!);
              }
              ref
                  .read(AllControllers.userController.notifier)
                  .updateUserModel(userModel);
              try {
                await ref
                    .read(AllControllers.chatViewController.notifier)
                    .getConversations();
                await ref
                    .read(AllControllers.agentsViewController.notifier)
                    .getAgents();
                await ref
                    .read(AllControllers.agentsViewController.notifier)
                    .getRecentAgents();
              } catch (e) {
                debugPrint("⚠️ Veri çekme hatası (devam ediliyor): $e");
              }
              await _ensureMinimumSplashVisible(splashStartedAt);
              await navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/bottomNavbar',
                (a) => false,
              );
            } else {
              debugPrint("⚠️ Token geçersiz, onboard ekranına yönlendiriliyor");
              await localService.setAuthTokens(accessToken: "", refreshToken: "");
              await _ensureMinimumSplashVisible(splashStartedAt);
              await navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/onboard',
                (a) => false,
              );
            }
          } catch (e) {
            debugPrint("⚠️ Token doğrulama hatası: $e");
            await _ensureMinimumSplashVisible(splashStartedAt);
            await navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/onboard',
              (a) => false,
            );
          }
        } else {
          debugPrint("Token bilgisi yok, onboard ekranına yönlendiriliyor");
          await _ensureMinimumSplashVisible(splashStartedAt);
          await navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/onboard',
            (a) => false,
          );
        }
      }
    } else if (appState == AppConfigState.maintenance) {
    } else {
      await _ensureMinimumSplashVisible(splashStartedAt);
      navigatorKey.currentState?.pushNamed('/serverError');
    }
  }

  Future<bool?> getFirstOpen() async {
    LocalService localService = LocalService(
      prefs: await SharedPreferences.getInstance(),
    );
    bool? firstOpen = await localService.getFirstOpen();
    return firstOpen;
  }

  Future<void> changeFirstOpen() async {
    LocalService localService = LocalService(
      prefs: await SharedPreferences.getInstance(),
    );
    await localService.changeFirstOpen(false);
  }

  Future<AppConfigState> getConfig() async {
    try {
      HttpService httpService = HttpService(ref: ref);
      var response = await httpService.post(path: AppConstants.configURL);
      if (response.statusCode == 200) {
        return AppConfigState.normal;
      } else {
        return AppConfigState.error;
      }
    } catch (e) {
      return AppConfigState.error;
    }
  }

  /// Uygulama versiyonunu kontrol eder ve güncelleme gerekliyse dialog gösterir
  Future<bool> checkAppVersion() async {
    try {
      // Mevcut uygulama versiyonunu al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint(
        "📱 Current app version: $currentVersion (build: $currentBuildNumber)",
      );

      // Backend'den minimum versiyon bilgisini al
      HttpService httpService = HttpService(ref: ref);
      var response = await httpService.post(path: AppConstants.configURL);

      if (response.statusCode == 200) {
        final configJson = jsonDecode(response.body);
        final minimumVersion = configJson['minimumVersion'] as String?;
        final minimumBuildNumber = configJson['minimumBuildNumber'] as int?;

        debugPrint(
          "🔍 Minimum required version: $minimumVersion (build: $minimumBuildNumber)",
        );

        if (minimumVersion != null) {
          // Versiyon karşılaştırması
          final needsUpdate = _compareVersions(
            currentVersion,
            minimumVersion,
            currentBuildNumber,
            minimumBuildNumber,
          );

          if (needsUpdate) {
            debugPrint("⚠️ App update required!");
            await _showForceUpdateDialog();
            return true; // Güncelleme gerekli
          }
        }
      }

      return false; // Güncelleme gerekli değil
    } on SocketException catch (e) {
      // Ağ bağlantı hatası - sessizce devam et
      debugPrint(
        "⚠️ Network error checking app version (continuing): ${e.message}",
      );
      return false;
    } on HandshakeException catch (e) {
      // SSL sertifika hatası - sessizce devam et
      // Bu hata genellikle geçici ağ sorunları veya sertifika zinciri sorunlarından kaynaklanır
      debugPrint(
        "⚠️ SSL certificate error checking app version (continuing): ${e.message}",
      );
      return false;
    } on TimeoutException catch (e) {
      // Zaman aşımı - sessizce devam et
      debugPrint("⚠️ Timeout checking app version (continuing): ${e.message}");
      return false;
    } catch (e) {
      // Diğer hatalar - sessizce devam et
      debugPrint("⚠️ Error checking app version (continuing): $e");
      return false; // Hata durumunda devam et
    }
  }

  /// Versiyonları karşılaştırır
  bool _compareVersions(
    String currentVersion,
    String minimumVersion,
    int currentBuild,
    int? minimumBuild,
  ) {
    // Önce build number'ı kontrol et (daha kesin)
    if (minimumBuild != null && currentBuild < minimumBuild) {
      return true; // Güncelleme gerekli
    }

    // Versiyon numaralarını karşılaştır (ör: "1.1.2" vs "1.2.0")
    final currentParts = currentVersion
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final minimumParts = minimumVersion
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    // Eksik kısımları 0 ile doldur
    while (currentParts.length < minimumParts.length) {
      currentParts.add(0);
    }
    while (minimumParts.length < currentParts.length) {
      minimumParts.add(0);
    }

    // Her seviyeyi karşılaştır
    for (int i = 0; i < currentParts.length; i++) {
      if (currentParts[i] < minimumParts[i]) {
        return true; // Güncelleme gerekli
      } else if (currentParts[i] > minimumParts[i]) {
        return false; // Güncel
      }
    }

    return false; // Aynı versiyon
  }

  /// Zorunlu güncelleme dialog'unu gösterir
  Future<void> _showForceUpdateDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // App Store/Play Store URL'leri
    final String storeUrl;
    if (Platform.isIOS) {
      // iOS App Store URL (bundle ID'yi kontrol et)
      storeUrl =
          'https://apps.apple.com/app/id6739936253'; // Gerçek App ID ile değiştirilmeli
    } else if (Platform.isAndroid) {
      // Google Play Store URL (package name ile)
      storeUrl =
          'https://play.google.com/store/apps/details?id=com.flywork.friendify';
    } else {
      return; // Desteklenmeyen platform
    }

    await showDialog(
      context: context,
      barrierDismissible: false, // Dialog kapatılamaz
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false, // Geri tuşu ile kapatılamaz
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.system_update, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Translate.translate(
                      TranslateKeys.forceUpdateTitle,
                      context,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Translate.translate(
                    TranslateKeys.forceUpdateMessage,
                    context,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                Text(
                  Translate.translate(TranslateKeys.forceUpdateHint, context),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  // App Store/Play Store'a yönlendir
                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  Translate.translate(TranslateKeys.forceUpdateAction, context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum SplashViewState { loading, done, initial }

enum AppConfigState { normal, maintenance, error }
