// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
final Locale locale;
  AppLocalizations(this.locale);

static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

 static AppLocalizations? of(BuildContext context){
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
 }

 Map<String , dynamic>? localizedStrings;

 Future<bool> load() async{
  debugPrint(locale.languageCode);
  String jsonString = await rootBundle.loadString("assets/langs/${locale.languageCode}.json");

  Map<String , dynamic> jsonMap = json.decode(jsonString);

  localizedStrings = jsonMap.map((key, value) {
    return MapEntry(key, value.toString());
  }
  );
  return true;
 }



String translate(String key){
  // Null-safe: Eğer key bulunamazsa key'i döndür (fallback)
  return localizedStrings![key] ?? key;
}
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale){
    return ['en','tr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async{
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false; 
}
