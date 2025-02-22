class ConversationEntity {
  final String id;
  final String lastMessageId;
  final String participantName;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageStatus;

  ConversationEntity({
    required this.id,
    required this.lastMessageId,
    required this.participantName,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageStatus,
  });
}
