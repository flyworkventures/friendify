class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final String? payload;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.payload,
    this.isRead = false,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    NotificationType? type,
    String? payload,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString().split('.').last,
      'payload': payload,
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      type: NotificationType.fromString(map['type'] as String? ?? 'system'),
      payload: map['payload'] as String?,
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}

enum NotificationType {
  system,      // Sistem bildirimi
  welcome,     // Hoşgeldiniz bildirimi
  trialStarted, // Trial başladı bildirimi
  trialEnded,   // Trial bitti bildirimi
  reminder;     // Hatırlatma bildirimi

  static NotificationType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'system':
        return NotificationType.system;
      case 'welcome':
        return NotificationType.welcome;
      case 'trialstarted':
      case 'trial_started':
        return NotificationType.trialStarted;
      case 'trialended':
      case 'trial_ended':
        return NotificationType.trialEnded;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.system;
    }
  }
}