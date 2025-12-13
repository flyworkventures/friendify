
class ChatModel {
  final int id;
  final int userId;
  final int botId;
  final String currentChatState;
  final String? lastMessage;
  final String? lastMessageAt;
  final dynamic startedAt;
  ChatModel({
    required this.id,
    required this.userId,
    required this.botId,
    required this.currentChatState,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.startedAt,
  });

  ChatModel copyWith({
    int? id,
    int? userId,
    int? botId,
    String? currentChatState,
    String? lastMessage,
    String? lastMessageAt,
    dynamic startedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      botId: botId ?? this.botId,
      currentChatState: currentChatState ?? this.currentChatState,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'botId': botId,
      'currentChatState': currentChatState,
      'lastMessage': lastMessage,
      'last_message_at': lastMessageAt,
      'started_at': startedAt,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] as int,
      userId: map['userId'] as int,
      botId: map['botId'] as int,
      currentChatState: map['current_chat_state'],
      lastMessage: map['lastMessage'],
      lastMessageAt: map['last_message_at'],
      startedAt: map['started_at'],
    );
  }

}
