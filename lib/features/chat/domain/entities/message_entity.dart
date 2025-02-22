class MessageEntity {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String createdAt;
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
