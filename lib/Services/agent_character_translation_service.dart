import 'package:flutter/foundation.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:translator/translator.dart';

/// Karakter açıklamalarını uygulama diline çevirir (bellek önbelleği + paralel istek).
class AgentCharacterTranslationService {
  AgentCharacterTranslationService._();
  static final AgentCharacterTranslationService instance =
      AgentCharacterTranslationService._();

  final GoogleTranslator _translator = GoogleTranslator();

  /// `agentId|lang` → çevrilmiş metin
  final Map<String, String> _byAgent = {};

  /// `lang|kaynakMetin` → çevrilmiş metin (aynı metin tekrar çevrilmez)
  final Map<String, String> _bySource = {};

  final Set<String> _inFlight = {};

  static String agentKey(int agentId, String lang) => '$agentId|$lang';

  static String _normalizeLang(String? langCode) {
    return (langCode ?? 'en').toLowerCase().split('_').first.split('-').first;
  }

  static String _translatorLang(String lang) {
    if (lang == 'zh') return 'zh-cn';
    return lang;
  }

  static bool _looksTurkish(String text) {
    if (RegExp(r'[ğıüşöçİĞÜŞÖÇ]').hasMatch(text)) return true;
    return RegExp(
      r'\b(ve|bir|için|ile|olan|kişilik|enerjik|yardımsever)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _textMatchesLang(String text, String lang) {
    if (text.isEmpty) return false;
    if (lang == 'tr') return _looksTurkish(text);
    if (lang == 'en') return !_looksTurkish(text);
    return false;
  }

  /// Çeviri için kaynak metin (önce EN, sonra TR, sonra character).
  static String canonicalSource(AgentModel agent) {
    final en = agent.getCharacterByLang('en').trim();
    if (en.isNotEmpty) return en;
    final tr = agent.getCharacterByLang('tr').trim();
    if (tr.isNotEmpty) return tr;
    return agent.character.trim();
  }

  String? cachedForAgent(int agentId, String langCode) {
    return _byAgent[agentKey(agentId, _normalizeLang(langCode))];
  }

  void clear() {
    _byAgent.clear();
    _bySource.clear();
    _inFlight.clear();
  }

  Future<String> resolveForAgent(AgentModel agent, String langCode) async {
    final lang = _normalizeLang(langCode);
    final key = agentKey(agent.id, lang);

    final hit = _byAgent[key];
    if (hit != null) return hit;

    final fromDb = agent.getCharacterByLang(lang).trim();
    if (fromDb.isNotEmpty && _textMatchesLang(fromDb, lang)) {
      _byAgent[key] = fromDb;
      return fromDb;
    }

    final source = canonicalSource(agent);
    if (source.isEmpty) {
      _byAgent[key] = '';
      return '';
    }

    if (_textMatchesLang(source, lang)) {
      _byAgent[key] = source;
      return source;
    }

    final translated = await _translateText(source, lang);
    _byAgent[key] = translated;
    return translated;
  }

  Future<String> _translateText(String source, String lang) async {
    final sourceKey = '$lang|$source';
    final cached = _bySource[sourceKey];
    if (cached != null) return cached;

    if (_inFlight.contains(sourceKey)) {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final done = _bySource[sourceKey];
        if (done != null) return done;
      }
    }

    _inFlight.add(sourceKey);
    try {
      final result = await _translator.translate(
        source,
        to: _translatorLang(lang),
        from: 'auto',
      );
      final text = result.text.trim().isNotEmpty ? result.text.trim() : source;
      _bySource[sourceKey] = text;
      return text;
    } catch (e) {
      debugPrint('[AgentCharacterTranslation] $e');
      _bySource[sourceKey] = source;
      return source;
    } finally {
      _inFlight.remove(sourceKey);
    }
  }

  Future<void> prefetchAgents(
    Iterable<AgentModel> agents,
    String langCode, {
    int concurrency = 12,
  }) async {
    final list = agents.toList();
    if (list.isEmpty) return;

    for (var i = 0; i < list.length; i += concurrency) {
      final end = (i + concurrency < list.length) ? i + concurrency : list.length;
      final chunk = list.sublist(i, end);
      await Future.wait(
        chunk.map((agent) => resolveForAgent(agent, langCode)),
      );
    }
  }
}
