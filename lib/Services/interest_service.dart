import 'dart:convert';

import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/interest_option.dart';
import 'package:friendfy/utils/app_constants.dart';

class InterestService {
  InterestService._();

  /// Herkese açık endpoint; `lang` API dokümantasyonundaki kodlardan biri olmalı.
  static Future<List<InterestOption>> fetchLocalized(String lang) async {
    final http = HttpService();
    final res = await http.post(
      path: AppConstants.interestsListLocalized,
      body: {'lang': lang},
    );

    if (res.statusCode != 200) {
      throw Exception('interests HTTP ${res.statusCode}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    if (map['success'] != true) {
      throw Exception(map['msg']?.toString() ?? 'interests success false');
    }

    final raw = map['interests'];
    if (raw is! List) {
      return [];
    }

    final list = raw
        .map((e) => InterestOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }
}
