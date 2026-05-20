import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:devicelocale/devicelocale.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Services/agent_character_translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  List<Locale> langs = [
    const Locale('tr', 'TR'),
    const Locale("en", "US"),
    const Locale('de', 'DE'),
    const Locale('it', 'IT'),
    const Locale('fr', 'FR'),
    const Locale('ja', 'JP'),
    const Locale('ru', 'RU'),
    const Locale('es', 'ES'),
    const Locale('ko', 'KR'),
    const Locale('hi', 'IN'),
    const Locale('pt', 'PT'),
    const Locale('zh', 'CN'),
  ];

  Locale? currentLang;

  Future<void> changeLang(Locale lang) async {
    currentLang = lang;
    AgentCharacterTranslationService.instance.clear();
    debugPrint("AppProvider lang : $currentLang");

    // Save to SharedPreferences for notification service
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_locale', lang.languageCode);
    } catch (e) {
      debugPrint("Error saving locale: $e");
    }

    notifyListeners();
  }

  Future<void> initLang() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('current_locale');
      if (savedCode != null && savedCode.isNotEmpty) {
        final saved = langs
            .where((l) => l.languageCode == savedCode)
            .cast<Locale?>()
            .firstWhere(
              (l) => l != null,
              orElse: () => null,
            );
        if (saved != null) {
          currentLang = saved;
          notifyListeners();
          return;
        }
      }

      final deviceLocale = await Devicelocale.currentAsLocale;
      final matched = langs
          .where((l) => l.languageCode == deviceLocale?.languageCode)
          .cast<Locale?>()
          .firstWhere(
            (l) => l != null,
            orElse: () => langs.first,
          );

      currentLang = matched ?? langs.first;
      await prefs.setString('current_locale', currentLang!.languageCode);
      notifyListeners();
    } catch (e) {
      debugPrint("Error initializing locale: $e");
      currentLang ??= langs.first;
      notifyListeners();
    }
  }

  localeResCallBack(Locale? locales, Iterable<Locale> supportedLocales) {
    if (currentLang != null) {
      return currentLang;
    } else {
      for (var supportedLocale in supportedLocales) {
        if (supportedLocale.languageCode == locales?.languageCode &&
            supportedLocale.countryCode == locales?.countryCode) {
          debugPrint("Supported Lang: ${supportedLocale.languageCode}");
          changeLang(supportedLocales.first);
          notifyListeners();
        }

        return supportedLocales.first;
      }
    }
  }
}

final appProvider = ChangeNotifierProvider((context) => AppProvider());
