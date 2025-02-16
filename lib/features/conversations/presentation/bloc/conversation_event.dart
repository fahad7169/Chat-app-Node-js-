abstract class ConversationsEvent {}

class FetchConversations extends ConversationsEvent {}


class UpdateConversation extends ConversationsEvent {
  final String conversationId;
  final String lastMessage;
  final DateTime lastMessageTime;

  UpdateConversation({
    required this.conversationId,
    required this.lastMessage,
    required this.lastMessageTime,
  });
}
