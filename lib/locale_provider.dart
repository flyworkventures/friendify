import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:devicelocale/devicelocale.dart';
import 'package:flutter_riverpod/legacy.dart';
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

  changeLang(Locale lang) async {
    currentLang = lang;
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

  initLang() async {
    Locale? devicelocale = await Devicelocale.currentAsLocale;
    for (var element in langs) {
      if (devicelocale?.languageCode == element.languageCode) {
        currentLang = element;
        debugPrint("Current Locale $currentLang");

        // Save to SharedPreferences for notification service
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_locale', element.languageCode);
        } catch (e) {
          debugPrint("Error saving locale: $e");
        }
      }
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
