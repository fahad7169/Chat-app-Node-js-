import 'package:hive/hive.dart';


part 'message_entity.g.dart'; // ✅ Make sure this matches your filename

@HiveType(typeId: 2) // ✅ Register a unique typeId for the model
class MessageEntity {
  @HiveField(9)
  final String id;
  @HiveField(10)
  final String conversationId;
  @HiveField(11)
  final String senderId;
  @HiveField(12)
  final String content;
  @HiveField(13)
  final String createdAt;
  @HiveField(14)
  final String? status;

  MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.status,
  });

  MessageEntity copyWith({String? status}) {
    return MessageEntity(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      status: status,
    );
  }

}
