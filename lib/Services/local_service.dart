import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:friendfy/Local/local_db_keys.dart';
import 'package:random_string/random_string.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalService {
  final SharedPreferences prefs;

  LocalService({required this.prefs});

  Future<bool?> getFirstOpen()async{
    final isFirstOpen = prefs.getBool(LocalDbKeys.firstLogin);
    return isFirstOpen;
  }

    Future<void> changeFirstOpen(bool value)async{
    await prefs.setBool(LocalDbKeys.firstLogin,value);
  }




  Future<String?> getToken()async{
    final token = prefs.getString(LocalDbKeys.authToken);
    return token;
  }


    Future<bool?> setToken(String newToken)async{
    try {
      bool updated = await prefs.setString(LocalDbKeys.authToken,newToken);
      return updated;
    } catch (e) {
      debugPrint("Token güncellenirken bir sorun oluştu. $e");
      return false;
    }

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
    
    // Bugün ilk mesaj mı?
    if (lastDate != todayString) {
      // Farklı bir gün, sayacı sıfırla
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
    
    // Bugün ilk fotoğraf mı?
    if (lastDate != todayString) {
      // Farklı bir gün, sayacı sıfırla
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