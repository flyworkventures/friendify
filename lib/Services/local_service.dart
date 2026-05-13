import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:friendfy/Local/local_db_keys.dart';
import 'package:random_string/random_string.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalService {
  final SharedPreferences prefs;

  LocalService({required this.prefs});

  Future<bool?> getFirstOpen() async {
    final isFirstOpen = prefs.getBool(LocalDbKeys.firstLogin);
    return isFirstOpen;
  }

  Future<void> changeFirstOpen(bool value) async {
    await prefs.setBool(LocalDbKeys.firstLogin, value);
  }

  Future<String?> getToken() async {
    final token = prefs.getString(LocalDbKeys.authToken);
    return token;
  }

  Future<String?> getRefreshToken() async {
    final token = prefs.getString(LocalDbKeys.refreshToken);
    return token;
  }

  Future<bool?> setToken(String newToken) async {
    try {
      bool updated = await prefs.setString(LocalDbKeys.authToken, newToken);
      return updated;
    } catch (e) {
      debugPrint("Token güncellenirken bir sorun oluştu. $e");
      return false;
    }
  }

  Future<bool?> setRefreshToken(String newToken) async {
    try {
      bool updated = await prefs.setString(LocalDbKeys.refreshToken, newToken);
      return updated;
    } catch (e) {
      debugPrint("Refresh token güncellenirken bir sorun oluştu. $e");
      return false;
    }
  }

  Future<void> setAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await setToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await setRefreshToken(refreshToken);
    }
  }

  String? getPostAuthAction() {
    return prefs.getString(LocalDbKeys.postAuthAction);
  }

  Future<void> setPostAuthAction(String action) async {
    await prefs.setString(LocalDbKeys.postAuthAction, action);
  }

  Future<void> clearPostAuthAction() async {
    await prefs.remove(LocalDbKeys.postAuthAction);
  }

  Map<String, dynamic>? getOnboardingAnswers() {
    final raw = prefs.getString(LocalDbKeys.onboardingAnswers);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint("Onboarding cevapları okunurken hata: $e");
    }
    return null;
  }

  Future<void> saveOnboardingAnswers(Map<String, dynamic> answers) async {
    await prefs.setString(LocalDbKeys.onboardingAnswers, jsonEncode(answers));
  }

  Map<String, dynamic>? getOnboardingPendingAuth() {
    final raw = prefs.getString(LocalDbKeys.onboardingPendingAuth);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint("Onboarding pending auth okunurken hata: $e");
    }
    return null;
  }

  Future<void> saveOnboardingPendingAuth(Map<String, dynamic> authData) async {
    await prefs.setString(
      LocalDbKeys.onboardingPendingAuth,
      jsonEncode(authData),
    );
  }

  Future<void> clearOnboardingPendingAuth() async {
    await prefs.remove(LocalDbKeys.onboardingPendingAuth);
  }

  bool isOnboardingFunnelActive() {
    return prefs.getBool(LocalDbKeys.onboardingFunnelActive) ?? false;
  }

  Future<void> setOnboardingFunnelActive(bool value) async {
    await prefs.setBool(LocalDbKeys.onboardingFunnelActive, value);
  }

  bool isOnboardingGuestSession() {
    return prefs.getBool(LocalDbKeys.onboardingGuestSession) ?? false;
  }

  Future<void> setOnboardingGuestSession(bool value) async {
    await prefs.setBool(LocalDbKeys.onboardingGuestSession, value);
  }

  bool isOnboardingVideoGatePending() {
    return prefs.getBool(LocalDbKeys.onboardingVideoGatePending) ?? false;
  }

  Future<void> setOnboardingVideoGatePending(bool value) async {
    await prefs.setBool(LocalDbKeys.onboardingVideoGatePending, value);
  }

  static String selectedAgentPhotoKey(int agentId) {
    return "${LocalDbKeys.selectedAgentPhotoPrefix}$agentId";
  }

  static Future<void> saveSelectedAgentPhoto({
    required int agentId,
    required String photoUrl,
  }) async {
    if (photoUrl.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedAgentPhotoKey(agentId), photoUrl.trim());
  }

  static Future<String?> getSelectedAgentPhoto(int agentId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(selectedAgentPhotoKey(agentId));
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static Future<bool> deleteData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(key);
    } catch (e) {
      debugPrint("Veri silinirken bir sorun oluştu. $e");
      return false;
    }
  }

  /// Günlük mesaj sayısını alır (bugünkü)
  Future<int> getDailyMessageCount() async {
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    final lastDate = prefs.getString(LocalDbKeys.dailyMessageDate);

    if (lastDate != todayString) {
      await prefs.setInt(LocalDbKeys.dailyMessageCount, 0);
      await prefs.setString(LocalDbKeys.dailyMessageDate, todayString);
      return 0;
    }

    return prefs.getInt(LocalDbKeys.dailyMessageCount) ?? 0;
  }

  /// Günlük mesaj sayısını artırır
  Future<void> incrementDailyMessageCount() async {
    final count = await getDailyMessageCount();
    await prefs.setInt(LocalDbKeys.dailyMessageCount, count + 1);

    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    await prefs.setString(LocalDbKeys.dailyMessageDate, todayString);
  }

  /// Günlük mesaj sayısını sıfırlar
  Future<void> resetDailyMessageCount() async {
    await prefs.setInt(LocalDbKeys.dailyMessageCount, 0);
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    await prefs.setString(LocalDbKeys.dailyMessageDate, todayString);
  }

  /// Günlük fotoğraf sayısını alır (bugünkü)
  Future<int> getDailyPhotoCount() async {
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    final lastDate = prefs.getString(LocalDbKeys.dailyPhotoDate);

    if (lastDate != todayString) {
      await prefs.setInt(LocalDbKeys.dailyPhotoCount, 0);
      await prefs.setString(LocalDbKeys.dailyPhotoDate, todayString);
      return 0;
    }

    return prefs.getInt(LocalDbKeys.dailyPhotoCount) ?? 0;
  }

  /// Günlük fotoğraf sayısını artırır
  Future<void> incrementDailyPhotoCount() async {
    final count = await getDailyPhotoCount();
    await prefs.setInt(LocalDbKeys.dailyPhotoCount, count + 1);

    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    await prefs.setString(LocalDbKeys.dailyPhotoDate, todayString);
  }

  /// Günlük fotoğraf sayısını sıfırlar
  Future<void> resetDailyPhotoCount() async {
    await prefs.setInt(LocalDbKeys.dailyPhotoCount, 0);
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    await prefs.setString(LocalDbKeys.dailyPhotoDate, todayString);
  }

  /// Günlük sesli mesaj sayısını alır (bugünkü)
  Future<int> getDailyAudioCount() async {
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    final lastDate = prefs.getString(LocalDbKeys.dailyAudioDate);

    if (lastDate != todayString) {
      await prefs.setInt(LocalDbKeys.dailyAudioCount, 0);
      await prefs.setString(LocalDbKeys.dailyAudioDate, todayString);
      return 0;
    }

    return prefs.getInt(LocalDbKeys.dailyAudioCount) ?? 0;
  }

  /// Günlük sesli mesaj sayısını artırır
  Future<void> incrementDailyAudioCount() async {
    final count = await getDailyAudioCount();
    await prefs.setInt(LocalDbKeys.dailyAudioCount, count + 1);

    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    await prefs.setString(LocalDbKeys.dailyAudioDate, todayString);
  }

  /// Günlük sesli mesaj sayısını sıfırlar
  Future<void> resetDailyAudioCount() async {
    await prefs.setInt(LocalDbKeys.dailyAudioCount, 0);
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    await prefs.setString(LocalDbKeys.dailyAudioDate, todayString);
  }

  /// Toplam düzenlenen karakter sayısını alır
  Future<int> getCharacterEditCount() async {
    return prefs.getInt(LocalDbKeys.characterEditCount) ?? 0;
  }

  /// Toplam düzenlenen karakter sayısını artırır
  Future<void> incrementCharacterEditCount() async {
    final count = await getCharacterEditCount();
    await prefs.setInt(LocalDbKeys.characterEditCount, count + 1);
  }

  /// Toplam düzenlenen karakter sayısını sıfırlar
  Future<void> resetCharacterEditCount() async {
    await prefs.setInt(LocalDbKeys.characterEditCount, 0);
  }

  /// UUID oluşturucu fonksiyon
  String _generateUUID() {
    var randomString = randomNumeric(15);
    return randomString;
  }

  /// Misafir kullanıcı için device ID alır veya oluşturur
  Future<String> getOrCreateGuestDeviceId() async {
    String? deviceId = prefs.getString(LocalDbKeys.guestDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateUUID();
      await prefs.setString(LocalDbKeys.guestDeviceId, deviceId);
      debugPrint("🆕 New guest device ID created: $deviceId");
    }
    return deviceId;
  }

  /// Misafir kullanıcı device ID'yi alır
  Future<String?> getGuestDeviceId() async {
    return prefs.getString(LocalDbKeys.guestDeviceId);
  }
}
