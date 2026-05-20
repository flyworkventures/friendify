
import 'dart:convert';

class AgentModel {
  final String name;
  final String creatorId;
  final String character;
  final String characterTags;
  final List<String> photoURLs;
  final int system;
  final int id;
  final String gender;
  final int age;
  final String? speakingStyle;
  final String? characterLocalized;
  final String? characterTr;
  final String? characterEn;
  final String? characterIt;
  final String? characterDe;
  final String? characterJa;
  final String? characterFr;
  final String? characterEs;
  final String? characterKo;
  final String? characterHi;
  final String? characterPt;
  final dynamic interests;
  final dynamic interestsType;
  final String? voiceId;
  final String country;
  final String? riveAvatar;
  final String? jobTr;
  final String? jobEn;
  final String? jobIt;
  final String? jobDe;
  final String? jobJa;
  final String? jobFr;
  final String? jobEs;
  final String? jobKo;
  final String? jobHi;
  final String? jobPt;
  AgentModel({
    required this.name,
    required this.creatorId,
    required this.character,
    required this.characterTags,
    required this.photoURLs,
    required this.system,
    required this.id,
    required this.gender,
    required this.age,
    required this.speakingStyle,
    this.characterLocalized,
    this.characterTr,
    this.characterEn,
    this.characterIt,
    this.characterDe,
    this.characterJa,
    this.characterFr,
    this.characterEs,
    this.characterKo,
    this.characterHi,
    this.characterPt,
    required this.interests,
    required this.interestsType,
    required this.voiceId,
    required this.country,
    this.riveAvatar,
    this.jobTr,
    this.jobEn,
    this.jobIt,
    this.jobDe,
    this.jobJa,
    this.jobFr,
    this.jobEs,
    this.jobKo,
    this.jobHi,
    this.jobPt,
  });

  String get photoURL => photoURLs.isNotEmpty ? photoURLs.first : '';

  static const List<String> supportedJobLangs = [
    'tr', 'en', 'it', 'de', 'ja', 'fr', 'es', 'ko', 'hi', 'pt'
  ];

  String? getJobByLang(String? langCode) {
    final normalized = (langCode ?? 'en').toLowerCase().split('_').first.split('-').first;
    switch (normalized) {
      case 'tr':
        return jobTr ?? jobEn;
      case 'en':
        return jobEn ?? jobTr;
      case 'it':
        return jobIt ?? jobEn ?? jobTr;
      case 'de':
        return jobDe ?? jobEn ?? jobTr;
      case 'ja':
        return jobJa ?? jobEn ?? jobTr;
      case 'fr':
        return jobFr ?? jobEn ?? jobTr;
      case 'es':
        return jobEs ?? jobEn ?? jobTr;
      case 'ko':
        return jobKo ?? jobEn ?? jobTr;
      case 'hi':
        return jobHi ?? jobEn ?? jobTr;
      case 'pt':
        return jobPt ?? jobEn ?? jobTr;
      default:
        return jobEn ?? jobTr;
    }
  }

  Map<String, String?> get jobsByLanguage => {
    'tr': jobTr,
    'en': jobEn,
    'it': jobIt,
    'de': jobDe,
    'ja': jobJa,
    'fr': jobFr,
    'es': jobEs,
    'ko': jobKo,
    'hi': jobHi,
    'pt': jobPt,
  };

  static bool _looksTurkish(String text) {
    if (RegExp(r'[ğıüşöçİĞÜŞÖÇ]').hasMatch(text)) return true;
    return RegExp(
      r'\b(ve|bir|için|ile|olan|kişilik|enerjik|yardımsever)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _textMatchesLang(String text, String lang) {
    if (lang == 'tr') return _looksTurkish(text);
    if (lang == 'en') return !_looksTurkish(text);
    return false;
  }

  String getCharacterByLang(String? langCode) {
    final normalized = (langCode ?? 'en')
        .toLowerCase()
        .split('_')
        .first
        .split('-')
        .first;
    final byLang = switch (normalized) {
      'tr' => characterTr,
      'en' => characterEn,
      'it' => characterIt,
      'de' => characterDe,
      'ja' => characterJa,
      'fr' => characterFr,
      'es' => characterEs,
      'ko' => characterKo,
      'hi' => characterHi,
      'pt' => characterPt,
      _ => null,
    }?.trim();
    if (byLang != null && byLang.isNotEmpty) {
      return byLang;
    }

    final base = character.trim();
    if (base.isNotEmpty) return base;

    final localized = characterLocalized?.trim();
    if (localized != null &&
        localized.isNotEmpty &&
        _textMatchesLang(localized, normalized)) {
      return localized;
    }

    return (speakingStyle ?? '').trim();
  }


  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'creatorId': creatorId,
      'character': character,
      'characterTags': characterTags,
      'photoURL': photoURL,
      'photoURLs': photoURLs,
      'system': system,
      'id': id,
      'gender': gender,
      'age': age,
      'speakingStyle': speakingStyle,
      'character_localized': characterLocalized,
      'character_tr': characterTr,
      'character_en': characterEn,
      'character_it': characterIt,
      'character_de': characterDe,
      'character_ja': characterJa,
      'character_fr': characterFr,
      'character_es': characterEs,
      'character_ko': characterKo,
      'character_hi': characterHi,
      'character_pt': characterPt,
      'interests': interests,
      'interestsType': interestsType,
      'voiceId': voiceId,
      'country': country,
      'rive_avatar': riveAvatar,
      'job_tr': jobTr,
      'job_en': jobEn,
      'job_it': jobIt,
      'job_de': jobDe,
      'job_ja': jobJa,
      'job_fr': jobFr,
      'job_es': jobEs,
      'job_ko': jobKo,
      'job_hi': jobHi,
      'job_pt': jobPt,

    };
  }

  factory AgentModel.fromMap(Map<String, dynamic> map) {
    return AgentModel(
      id: map["id"],
      name: map['name'] as String,
      creatorId: map['creatorId'] as String,
      character: map['character'] as String,
      characterTags: map['characterTags'] as dynamic,
      photoURLs: _parsePhotoUrls(map),
      system: map['system'] as int,
      gender: map['gender'] as String,
      age: map['age'] as int,
      speakingStyle: map['speakingStyle'],
      characterLocalized:
          map['character_localized'] ??
          map['characterLocalized'] ??
          map['character_description'] ??
          map['characterDescription'],
      characterTr: map['character_tr'],
      characterEn: map['character_en'],
      characterIt: map['character_it'],
      characterDe: map['character_de'],
      characterJa: map['character_ja'],
      characterFr: map['character_fr'],
      characterEs: map['character_es'],
      characterKo: map['character_ko'],
      characterHi: map['character_hi'],
      characterPt: map['character_pt'],
      interests: map['interests'] as dynamic,
      interestsType: map['interestsType'] as dynamic,
      voiceId: map['voiceId'],
      country: map['country'] as String,
      riveAvatar: _parseRiveAvatar(map),
      jobTr: map['job_tr'],
      jobEn: map['job_en'],
      jobIt: map['job_it'],
      jobDe: map['job_de'],
      jobJa: map['job_ja'],
      jobFr: map['job_fr'],
      jobEs: map['job_es'],
      jobKo: map['job_ko'],
      jobHi: map['job_hi'],
      jobPt: map['job_pt'],
    );
  }

  static List<String> _parsePhotoUrls(Map<String, dynamic> map) {
    final dynamic raw = map['photoURLs'] ?? map['photo_urls'] ?? map['photoURL'];
    if (raw == null) {
      return const [];
    }
    if (raw is List) {
      return raw.whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return const [];
      }
      if (trimmed.startsWith('[')) {
        try {
          final dynamic parsed = jsonDecode(trimmed);
          if (parsed is List) {
            return parsed.whereType<String>().where((e) => e.trim().isNotEmpty).toList();
          }
        } catch (_) {
          return [trimmed];
        }
      }
      return [trimmed];
    }
    return const [];
  }

  static String? _parseRiveAvatar(Map<String, dynamic> map) {
    // Backend bazı uçlarda Rive dosyasını `avatarUrl` / `avatar_url` ile döndürüyor.
    final dynamic raw = map['rive_avatar'] ??
        map['riveAvatar'] ??
        map['rive_avatar_url'] ??
        map['riveAvatarUrl'] ??
        map['avatar_rive'] ??
        map['avatarRive'] ??
        map['avatarUrl'] ??
        map['avatar_url'] ??
        map['avatarurl'];
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is Map<String, dynamic>) {
      final dynamic nested = raw['url'] ?? raw['src'] ?? raw['path'];
      if (nested is String) {
        final trimmed = nested.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
    }
    return raw.toString().trim().isEmpty ? null : raw.toString().trim();
  }
}
