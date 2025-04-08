abstract class ChatEvent {}

class LoadMessagesEvent extends ChatEvent {
  final String conversationId;

  LoadMessagesEvent(this.conversationId);
}

class SendMessageEvent extends ChatEvent {
  final String conversationId;
  final String content;
  final String contactId; // Add contact ID field

  SendMessageEvent(this.conversationId, this.content, this.contactId);
}

class ReceiveMessageEvent extends ChatEvent {
  final Map<String, dynamic> message;

  ReceiveMessageEvent(this.message);
}


class MessageSeenEvent extends ChatEvent {
  final String messageId;
  final String conversationId;

  MessageSeenEvent(this.messageId,this.conversationId);
}
 
class TypingStartedEvent extends ChatEvent{
  final String conversationId;

  TypingStartedEvent(this.conversationId);
}

class TypingStopped extends ChatEvent {
  final String conversationId;
  TypingStopped(this.conversationId);
}

class MessageStatusUpdatedEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String status;

  MessageStatusUpdatedEvent(this.conversationId, this.messageId, this.status);
}

class RefreshUiEvent extends ChatEvent {}

class RefreshMessagesFromHiveEvent extends ChatEvent {
  String conversationId;

  RefreshMessagesFromHiveEvent(this.conversationId);
}