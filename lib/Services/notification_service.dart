import 'dart:convert';
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:friendfy/Models/notification_model.dart';
import 'package:friendfy/Local/local_db_keys.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'Friendify_reminder';
  static const String _channelName = 'Friendify Reminders';
  static const String _channelDescription = 'Notifications to remind you to check Friendify';
  
  // Sistem bildirimleri için channel
  static const String _systemChannelId = 'Friendify_system';
  static const String _systemChannelName = 'Friendify System Notifications';
  static const String _systemChannelDescription = 'System notifications from Friendify';


  /// Initialize notification service
  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    
    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings - Apple guidelines: Don't request permission on initialization
    // Permission will be requested later when appropriate
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Don't request permissions here - will be requested later when appropriate
    log('✅ Notification Service initialized (permissions will be requested when needed)');
  }

  /// Check if notification permission has been asked before
  static Future<bool> hasAskedPermissionBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_permission_asked') ?? false;
  }

  /// Mark that notification permission has been asked (without actually requesting)
  /// This is used when user clicks "Not Now" to prevent asking again
  static Future<void> markPermissionAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_asked', true);
    log('ℹ️ Notification permission dialog shown, marked as asked');
  }

  /// Check current notification permission status
  /// Returns true if permission is granted, false otherwise
  static Future<bool> checkNotificationPermission() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.areNotificationsEnabled();
        log('📱 Android notification permission status: ${granted ?? false}');
        return granted ?? false;
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        // Check permissions for iOS
        final settings = await iosPlugin.checkPermissions();
        final granted = settings?.isAlertEnabled == true && settings?.isBadgeEnabled == true && settings?.isSoundEnabled == true;
       // log('📱 iOS notification permission status: $granted (alert: ${settings.alert}, badge: ${settings.badge}, sound: ${settings.sound})');
        return granted;
      }
      
      return false;
    } catch (e) {
      log('❌ Error checking notification permission: $e');
      return false;
    }
  }

  /// Request notification permissions (only call this once, when appropriate)
  /// Returns true if permission was granted, false otherwise
  /// This follows Apple guidelines: request permission only when appropriate (e.g., after user logs in)
  static Future<bool> requestNotificationPermission() async {
    try {
      // Check if we've already asked for permission
      final prefs = await SharedPreferences.getInstance();
      final hasAskedBefore = prefs.getBool('notification_permission_asked') ?? false;
      
      // If we've asked before, don't ask again (Apple guideline)
      // User can enable it from Settings if they want
      if (hasAskedBefore) {
        log('ℹ️ Notification permission was already asked. User can enable from Settings.');
        // But still check current status and return it
        return await checkNotificationPermission();
      }
      
      // Mark that we're about to ask for permission
      await prefs.setBool('notification_permission_asked', true);
      
      // Request permissions (only once)
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        log('📱 Android notification permission: ${granted ?? false}');
        // Save permission status
        await prefs.setBool('notification_permission_granted', granted ?? false);
        return granted ?? false;
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        // Request permissions for iOS
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
        // iOS'ta requestPermissions her zaman doğru sonucu döndürmeyebilir
        // Bu yüzden gerçek izin durumunu kontrol etmek için checkPermissions kullan
        await Future.delayed(Duration(milliseconds: 300)); // İzin dialog'unun kapanmasını bekle
        
        final actualStatus = await checkNotificationPermission();
        log('📱 iOS notification permission requested, actual status: $actualStatus');
        
        // Save permission status
        await prefs.setBool('notification_permission_granted', actualStatus);
        return actualStatus;
      }
      
      return false;
    } catch (e) {
      log('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    log('Notification tapped: ${response.payload}');
    
    // Bildirime tıklandığında yapılacak işlemler
    // (Örneğin: belirli bir ekrana yönlendirme)
  }

  /// Show a notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );

    log('Notification shown: $title - $body');
  }

  /// Show a system notification (with app icon)
  /// System notifications are shown in the notifications screen
  static Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
    int? notificationId,
  }) async {
    // Android için sistem bildirimi (uygulama ikonu ile)
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _systemChannelId,
      _systemChannelName,
      channelDescription: _systemChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher', // Uygulama ikonu
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = notificationId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );

    log('System notification shown: $title - $body (ID: $id)');
    
    // Bildirimi notifications listesine ekle (sistem bildirimleri için)
    await _saveNotificationToHistory(title, body, payload);
  }
  
  /// Kullanıcı ID'sine göre bildirim key'i oluştur
  static String _getNotificationsKey(String? userId) {
    if (userId == null) {
      return LocalDbKeys.notifications; // Fallback (kullanıcı yoksa)
    }
    return "${LocalDbKeys.notifications}_$userId"; // Kullanıcı bazlı key
  }

  /// Bildirimi notifications listesine kaydet (kullanıcı bazlı)
  static Future<void> _saveNotificationToHistory(
    String title,
    String body,
    String? payload,
  ) async {
    try {
      // Not: Bu static method olduğu için ref'e erişemiyoruz
      // Bildirimler artık NotificationsViewController üzerinden eklenecek
      // Bu method artık kullanılmıyor, sadece eski kod uyumluluğu için bırakıldı
      final prefs = await SharedPreferences.getInstance();
      String? userId = null; // Kullanıcı ID'si alınamıyor (static method)
      final notificationsKey = _getNotificationsKey(userId);
      final notificationsJson = prefs.getString(notificationsKey);
      
      List<NotificationModel> notifications = [];
      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        notifications = decoded
            .map((item) => NotificationModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      
      // Notification type'ı belirle
      NotificationType type = NotificationType.system;
      if (payload == 'welcome') {
        type = NotificationType.welcome;
      } else if (payload == 'trial_started') {
        type = NotificationType.trialStarted;
      } else if (payload == 'trial_ended') {
        type = NotificationType.trialEnded;
      }
      
      // Yeni bildirimi ekle
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        createdAt: DateTime.now(),
        type: type,
        payload: payload,
      );
      
      // Aynı ID'ye sahip bildirim varsa ekleme (duplicate kontrolü)
      if (!notifications.any((n) => n.id == notification.id)) {
        notifications.add(notification);
        // Tarihe göre sırala (en yeni üstte)
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Kaydet (kullanıcı bazlı key ile)
        final updatedJson = json.encode(
          notifications.map((n) => n.toMap()).toList(),
        );
        await prefs.setString(notificationsKey, updatedJson);
        log('✅ Notification saved to history: $title');
      } else {
        log('ℹ️ Notification already exists in history: $title');
      }
    } catch (e) {
      log('❌ Error saving notification to history: $e');
    }
  }

  /// Schedule a system notification for a specific time
  /// When the notification is shown, it will be automatically added to notifications history
  static Future<void> scheduleSystemNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    int? notificationId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _systemChannelId,
      _systemChannelName,
      channelDescription: _systemChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher', // Uygulama ikonu
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = notificationId ?? scheduledDate.millisecondsSinceEpoch ~/ 1000;
    
    // Convert to timezone-aware datetime
    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);
    
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    log('System notification scheduled: $title - $body (ID: $id, Date: $scheduledDate)');
    
    // Trial bitiş bildirimi ise, şimdi notifications listesine ekle (zamanlanmış bildirimler için)
    if (payload == 'trial_ended') {
      await _saveScheduledNotificationToHistory(title, body, scheduledDate, payload);
    }
  }

  /// Zamanlanmış bildirimi notifications listesine kaydet (kullanıcı bazlı)
  /// Not: Bu metod artık kullanılmıyor, bildirimler NotificationsViewController üzerinden eklenecek
  static Future<void> _saveScheduledNotificationToHistory(
    String title,
    String body,
    DateTime scheduledDate,
    String? payload,
  ) async {
    try {
      // Kullanıcı ID'sini almak için SharedPreferences'tan token'ı kontrol edebiliriz
      // Ama daha iyi bir çözüm: Bildirimleri NotificationsViewController üzerinden eklemek
      // Bu metod artık kullanılmıyor, bildirimler NotificationsViewController üzerinden eklenecek
      log('⚠️ _saveScheduledNotificationToHistory is deprecated, use NotificationsViewController instead');
    } catch (e) {
      log('❌ Error saving scheduled notification to history: $e');
    }
  }

  /// Start periodic notifications (every 30 minutes when app is closed)
  static Future<void> startPeriodicNotifications() async {
    try {
      // Both Android and iOS use scheduled notifications
      await _schedulePeriodicNotifications();
      log('✅ Periodic notifications scheduled');
    } catch (e) {
      log('❌ Error starting periodic notifications: $e');
    }
  }

  /// Schedule periodic notifications (works for both Android and iOS)
  static Future<void> _schedulePeriodicNotifications() async {
    try {
      // Mevcut bildirimleri iptal et
      await _notifications.cancelAll();
      
      // Get notification texts
      final texts = await _getNotificationTexts();
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Schedule notifications for next 24 hours (every 2-3 hours)
      // Both Android and iOS support zonedSchedule
      int notificationId = 1;
      
      // Schedule multiple notifications over the next 24 hours
      for (int hour = 2; hour <= 24; hour += 3) {
        final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(hours: hour));
        
        await _notifications.zonedSchedule(
          notificationId++,
          texts['title']!,
          texts['body']!,
          scheduledTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      
      log('✅ Scheduled periodic notifications for next 24 hours');
    } catch (e) {
      log('❌ Error scheduling periodic notifications: $e');
    }
  }

  /// Stop periodic notifications
  static Future<void> stopPeriodicNotifications() async {
    try {
      await _notifications.cancelAll();
      log('✅ Periodic notifications cancelled');
    } catch (e) {
      log('❌ Error stopping periodic notifications: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    await stopPeriodicNotifications();
    log('All notifications cancelled');
  }
}

/// Get notification texts based on saved language
Future<Map<String, String>> _getNotificationTexts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString('current_locale') ?? 'tr';
    
    final Map<String, Map<String, String>> translations = {
      'tr': {
        'title': '👋 Arkadaşların seni bekliyor!',
        'body': 'Friendify\'de seni merak eden arkadaşların var. Hemen sohbete başla!',
      },
      'en': {
        'title': '👋 Your friends are waiting for you!',
        'body': 'You have friends wondering about you on Friendify. Start chatting now!',
      },
      'de': {
        'title': '👋 Deine Freunde warten auf dich!',
        'body': 'Du hast Freunde, die sich auf Friendify nach dir erkundigen. Starte jetzt einen Chat!',
      },
      'es': {
        'title': '👋 ¡Tus amigos te están esperando!',
        'body': 'Tienes amigos que quieren saber de ti en Friendify. ¡Empieza a chatear ahora!',
      },
      'fr': {
        'title': '👋 Vos amis vous attendent !',
        'body': 'Vous avez des amis qui pensent à vous sur Friendify. Commencez à discuter maintenant !',
      },
      'it': {
        'title': '👋 I tuoi amici ti stanno aspettando!',
        'body': 'Hai amici che si chiedono come stai su Friendify. Inizia a chattare ora!',
      },
      'ja': {
        'title': '👋 友達があなたを待っています！',
        'body': 'Friendifyであなたのことを気にかけている友達がいます。今すぐチャットを始めましょう！',
      },
      'ko': {
        'title': '👋 친구들이 기다리고 있어요!',
        'body': 'Friendify에서 당신을 궁금해하는 친구들이 있어요. 지금 바로 채팅을 시작하세요!',
      },
      'ru': {
        'title': '👋 Ваши друзья ждут вас!',
        'body': 'На Friendify есть друзья, которые думают о вас. Начните общаться прямо сейчас!',
      },
      'hi': {
        'title': '👋 आपके दोस्त आपका इंतज़ार कर रहे हैं!',
        'body': 'Friendify पर आपके बारे में सोचने वाले दोस्त हैं। अभी चैट शुरू करें!',
      },
      'pt': {
        'title': '👋 Seus amigos estão esperando por você!',
        'body': 'Você tem amigos curiosos sobre você no Friendify. Comece a conversar agora!',
      },
      'zh': {
        'title': '👋 你的朋友正在等你！',
        'body': '在Friendify上有朋友想念你。现在就开始聊天吧！',
      },
    };
    
    return translations[langCode] ?? translations['tr']!;
  } catch (e) {
    log('Error getting notification texts: $e');
    return {
      'title': '👋 Arkadaşların seni bekliyor!',
      'body': 'Friendify\'de seni merak eden arkadaşların var. Hemen sohbete başla!',
    };
  }
}


