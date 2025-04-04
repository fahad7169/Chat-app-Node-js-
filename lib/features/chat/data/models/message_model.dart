import 'package:chat_app/features/chat/domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  MessageModel({
   required super.id,
   required super.conversationId,
  required super.senderId,
  required super.content,
  required super.createdAt,
  required String super.status,
  required super.contactId,
  });


  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: json['created_at'],
      status: json['status'],
      contactId: '',
    );
  }

}