// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/notification_model.dart';
import 'package:friendfy/Local/local_db_keys.dart';

class NotificationsViewController extends StateNotifier<NotificationsViewModel>{
  Ref? ref;
  NotificationsViewController(this.ref) : super(NotificationsViewModel(notifications: [])) {
    // Uygulama açıldığında bildirimleri yükle
    _loadNotifications();
  }

  /// Kullanıcı ID'sine göre bildirim key'i oluştur
  String _getNotificationsKey() {
    final userId = ref?.read(AllControllers.userController)?.id;
    if (userId == null) {
      return LocalDbKeys.notifications; // Fallback (kullanıcı yoksa)
    }
    return "${LocalDbKeys.notifications}_$userId"; // Kullanıcı bazlı key
  }

  /// Bildirimleri SharedPreferences'tan yükle (kullanıcı bazlı)
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsKey = _getNotificationsKey();
      final notificationsJson = prefs.getString(notificationsKey);
      
      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        final notifications = decoded
            .map((item) => NotificationModel.fromMap(item as Map<String, dynamic>))
            .toList();
        
        // Tarihe göre sırala (en yeni üstte)
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        state = state.copyWith(notifications: notifications);
        debugPrint("✅ Loaded ${notifications.length} notifications from storage for user");
      } else {
        debugPrint("ℹ️ No saved notifications found for current user");
        // Yeni kullanıcı için boş liste
        state = state.copyWith(notifications: []);
      }
    } catch (e) {
      debugPrint("❌ Error loading notifications: $e");
      state = state.copyWith(notifications: []);
    }
  }

  /// Bildirimleri SharedPreferences'a kaydet (kullanıcı bazlı)
  Future<void> _saveNotifications(List<NotificationModel> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsKey = _getNotificationsKey();
      final notificationsJson = json.encode(
        notifications.map((n) => n.toMap()).toList(),
      );
      await prefs.setString(notificationsKey, notificationsJson);
      debugPrint("✅ Saved ${notifications.length} notifications to storage for user");
    } catch (e) {
      debugPrint("❌ Error saving notifications: $e");
    }
  }
  
  /// Kullanıcı değiştiğinde bildirimleri yeniden yükle
  void reloadNotificationsForUser() {
    _loadNotifications();
  }

  /// Bildirim ekle (en yeni üstte)
  void addNotification(NotificationModel notification) {
    final currentNotifications = state.notifications ?? [];
    // Yeni bildirimi en başa ekle ve tarihe göre sırala (en yeni üstte)
    final updatedNotifications = [notification, ...currentNotifications];
    // Tarihe göre sırala (en yeni üstte)
    updatedNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(notifications: updatedNotifications);
    // Kalıcı olarak kaydet
    _saveNotifications(updatedNotifications);
  }

  /// Bildirimi okundu olarak işaretle
  void markAsRead(String notificationId) {
    final currentNotifications = state.notifications ?? [];
    final updatedNotifications = currentNotifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updatedNotifications);
    // Kalıcı olarak kaydet
    _saveNotifications(updatedNotifications);
  }

  /// Tüm bildirimleri okundu olarak işaretle
  void markAllAsRead() {
    final currentNotifications = state.notifications ?? [];
    final updatedNotifications = currentNotifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updatedNotifications);
    // Kalıcı olarak kaydet
    _saveNotifications(updatedNotifications);
  }

  /// Bildirimi sil
  void removeNotification(String notificationId) {
    final currentNotifications = state.notifications ?? [];
    final updatedNotifications = currentNotifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updatedNotifications);
    // Kalıcı olarak kaydet
    _saveNotifications(updatedNotifications);
  }
  
  /// Tüm bildirimleri temizle (logout için)
  Future<void> clearNotifications() async {
    try {
      state = state.copyWith(notifications: []);
      final prefs = await SharedPreferences.getInstance();
      final notificationsKey = _getNotificationsKey();
      await prefs.remove(notificationsKey);
      debugPrint("✅ Cleared all notifications for user");
    } catch (e) {
      debugPrint("❌ Error clearing notifications: $e");
    }
  }
}



class NotificationsViewModel {
  final List<NotificationModel>? notifications;
  final ScreenState screenState;

  NotificationsViewModel({this.notifications, this.screenState = ScreenState.normal});
  
  /// Sıralanmış bildirimler (en yeni üstte)
  List<NotificationModel> get sortedNotifications {
    if (notifications == null || notifications!.isEmpty) return [];
    final sorted = List<NotificationModel>.from(notifications!);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // En yeni üstte
    return sorted;
  }

  NotificationsViewModel copyWith({
    List<NotificationModel>? notifications,
    ScreenState? screenState,
  }) {
    return NotificationsViewModel(
      notifications:  notifications ?? this.notifications,
      screenState:  screenState ?? this.screenState,
    );
  }
}


enum ScreenState{
  loading,
  normal
}