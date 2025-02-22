import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';

class ConversationModel extends ConversationEntity {
  ConversationModel({
    required String id,
    required String lastMessageId,
    required String participantName,
    required String lastMessage,
    DateTime? lastMessageTime,
    required String lastMessageStatus,
  }) : super(
          id: id,
          participantName: participantName,
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          lastMessageStatus: lastMessageStatus,
          lastMessageId: lastMessageId,
        );

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['conversation_id'],
      participantName: json['participant_name'],
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] != null &&
              json['last_message_time'].toString().isNotEmpty
          ? DateTime.parse(json['last_message_time'])
          : null,
      lastMessageStatus: json['last_message_status'] ?? '',
      lastMessageId: json['last_message_id'] ?? '',
    );
  }

 
}
