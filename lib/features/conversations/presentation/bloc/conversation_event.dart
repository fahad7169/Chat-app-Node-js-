abstract class ConversationsEvent {}

class FetchConversations extends ConversationsEvent {}

class UpdateConversation extends ConversationsEvent {
  final String conversationId;
  final String lastMessageId;
  final String lastMessage;
  final String participantName;
  final DateTime lastMessageTime;
  final String lastMessageStatus;

  UpdateConversation({
    required this.conversationId,
    required this.lastMessageId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageStatus,
    required this.participantName,
  });
}

class LogoutEvent extends ConversationsEvent {}
