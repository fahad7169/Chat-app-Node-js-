abstract class ChatEvent {}

class LoadMessagesEvent extends ChatEvent {
  final String conversationId;

  LoadMessagesEvent(this.conversationId);
}

class SendMessageEvent extends ChatEvent {
  final String conversationId;
  final String content;

  SendMessageEvent(this.conversationId, this.content);
}

class ReceiveMessageEvent extends ChatEvent {
  final Map<String, dynamic> message;

  ReceiveMessageEvent(this.message);
}

class MessageDeliveredEvent extends ChatEvent{
  final String messageId;

  MessageDeliveredEvent(this.messageId);
}

class MessageSeenEvent extends ChatEvent{
  final String messageId;

  MessageSeenEvent(this.messageId);
}

class TypingStartedEvent extends ChatEvent{
  final String conversationId;

  TypingStartedEvent(this.conversationId);
}

class TypingStopped extends ChatEvent {
  final String conversationId;
  TypingStopped(this.conversationId);
}
