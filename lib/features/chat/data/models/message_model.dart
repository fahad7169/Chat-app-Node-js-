import 'package:chat_app/features/chat/domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  MessageModel({
   required String id,
   required String conversationId,
  required String senderId,
  required String content,
  required String createdAt,
  }):super(id: id, conversationId: conversationId, senderId: senderId, content: content, createdAt: createdAt);


  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: json['created_at'],
    );
  }

}