import 'package:friendfy/AppLocalizations/app_localizations.dart';

import 'package:flutter/material.dart';

class Translate{
  static String translate(String key,BuildContext context){
    return AppLocalizations.of(context)!.translate(key);
  }
}