// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class MessageModel {
  final int id;
  final String conversationId;
  final String sender;
  final dynamic message;
  final String createdAt;
  final String messageType;
  MessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.message,
    required this.createdAt,
    required this.messageType
  });



  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'conversationId': conversationId,
      'sender': sender,
      'message': message,
      'created_at': createdAt,
      'message_type': messageType,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as int,
      conversationId: map['conversationId'] as String,
      sender: map['sender'] as String,
      message: map['message'] as dynamic,
      createdAt: map['created_at'] as String,
      messageType: map['message_type'] as String,
    );
  }

}
