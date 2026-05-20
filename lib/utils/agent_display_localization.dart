import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Models/agent_model.dart';

class AgentDisplayLocalization {
  static String cardPreview(AgentModel agent, String? langCode) {
    final description = agent.getCharacterByLang(langCode).trim();
    if (description.isNotEmpty) return description;
    return agent.character.trim();
  }

  static List<String> localizedInterests(AgentModel agent, BuildContext context) {
    final keys = _asStringList(agent.interestsType);
    final rawLabels = _asStringList(agent.interests);

    if (keys.isEmpty && rawLabels.isEmpty) return const [];

    if (keys.isEmpty) {
      return rawLabels.where((e) => e.trim().isNotEmpty).toList();
    }

    final out = <String>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i].trim();
      if (key.isEmpty) continue;
      final translated = Translate.translate(key, context).trim();
      if (translated.isNotEmpty && translated != key) {
        out.add(translated);
      } else if (i < rawLabels.length && rawLabels[i].trim().isNotEmpty) {
        out.add(rawLabels[i].trim());
      } else {
        out.add(key);
      }
    }
    return out;
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      if (trimmed.startsWith('[')) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {
          return [trimmed];
        }
      }
      return [trimmed];
    }
    return [value.toString()];
  }
}
