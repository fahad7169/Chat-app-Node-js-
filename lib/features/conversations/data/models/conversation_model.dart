import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';
import 'package:hive/hive.dart';


part 'conversation_model.g.dart'; // ✅ Make sure this matches your filename

@HiveType(typeId: 0) // ✅ Register a unique typeId for the model
class ConversationModel extends ConversationEntity {  
  @HiveField(0)  
  final String id;

  @HiveField(1)  
  final String lastMessageId;

  @HiveField(2)  
  final String participantName;

  @HiveField(3)  
  final String lastMessage;

  @HiveField(4)  
  final DateTime? lastMessageTime;

  @HiveField(5)  
  final String lastMessageStatus;

  ConversationModel({
    required this.id,
    required this.lastMessageId,
    required this.participantName,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageStatus,
  }) : super(
          id: id,
          lastMessageId: lastMessageId,
          participantName: participantName,
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          lastMessageStatus: lastMessageStatus,
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
