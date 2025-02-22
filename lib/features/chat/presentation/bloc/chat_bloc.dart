import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/domain/usecases/fetch_messages_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collection/collection.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FetchMessagesUseCase fetchMessagesUseCase;

  final SocketService _socketService = SocketService();
  // Map for quick lookup of message index
  Map<String, int> _messageIndexMap = {};
  Map<String, String> tempIdMap = {}; // temp_id -> real_id

  List<MessageEntity> _messages = [];
  final _storage = FlutterSecureStorage();

  ChatBloc({required this.fetchMessagesUseCase}) : super(ChatLoadingState()) {
    on<LoadMessagesEvent>(_onloadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<MessageSeenEvent>(_onMessageSeen);
    on<TypingStartedEvent>(_onTypingStarted);
    on<TypingStopped>(_onTypingStopped);
    on<MessageStatusUpdatedEvent>(_onMessageStatusUpdated);
  }

  Future<void> _onloadMessages(
    LoadMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoadingState());

    try {
      final messages = await fetchMessagesUseCase.call(event.conversationId);
      _messages.clear();
      _messages.addAll(messages);
      emit(ChatLoadedState(List.from(_messages)));




     
    } catch (e) {
      emit(ChatErrorState("Error loading messages"));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    String userId = await _storage.read(key: "userId") ?? '';
    print("user id: $userId");

    final tempMessageId =
        DateTime.now().millisecondsSinceEpoch.toString(); // Unique temp ID

    // ✅ Store temp ID locally with content as key
    tempIdMap[tempMessageId] = event.content;

    final newMessage = MessageEntity(
      id: tempMessageId, // Temporary ID
      conversationId: event.conversationId,
      senderId: userId,
      content: event.content,
      createdAt: DateTime.now().toIso8601String(),
      status: 'pending', // Initially pending
    );

    // Add the message and store its index for quick lookup
    print("Adding message");
    _messages.add(newMessage);
    _messageIndexMap[tempMessageId] = _messages.length - 1;
    print("Saving message id in map: ${_messageIndexMap[tempMessageId]}");

    emit(ChatLoadedState(List.from(_messages))); // Update UI immediately

    final messageData = {
      'conversationId': event.conversationId,
      'content': event.content,
      'senderId': userId,
    };

    try {
      _socketService.socket.emit("sendMessage", messageData);

      if (_messageIndexMap.containsKey(tempMessageId)) {
        int? index = _messageIndexMap[tempMessageId];
        if (index != null && index >= 0 && index < _messages.length) {
          // Update the message status manually
          final updatedMessage = MessageEntity(
            id: _messages[index].id,
            conversationId: _messages[index].conversationId,
            senderId: _messages[index].senderId,
            content: _messages[index].content,
            createdAt: _messages[index].createdAt,
            status: "sent", // New status
          );
          _messages[index] = updatedMessage;
          emit(ChatLoadedState(List.from(_messages))); // Refresh UI
        } else {
          print("Error: Message index is out of bounds or null");
        }
      } else {
        print("Error: tempMessageId not found in _messageIndexMap");
      }
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  Future<void> _onReceiveMessage(
    ReceiveMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    print("Step 2 - receive event called");
    print(event.message);

    String userId = await _storage.read(key: "userId") ?? '';

    String realId = event.message['id'];
    String content = event.message['content'];
    String senderId = event.message['sender_id'];

    // ✅ Check if this message was sent by us (we need to update temp ID)
    if (senderId == userId) {
      print("✅ Updating temp ID to real ID before skipping");

      // Find temp message using content
      String? tempId =
          tempIdMap.entries
              .firstWhereOrNull((entry) => entry.value == content)
              ?.key;

      print("Temp ID: $tempId");

      if (tempId != null && _messageIndexMap.containsKey(tempId)) {
        int? index = _messageIndexMap[tempId];
        print("Index: $index");

        if (index != null && index >= 0 && index < _messages.length) {
          // ✅ Update local state by replacing temp ID with real ID
          print("Updating message: ${_messages[index]}");
          _messages[index] = MessageEntity(
            id: realId, // ✅ Replace temp ID with real ID
            conversationId: _messages[index].conversationId,
            senderId: _messages[index].senderId,
            content: _messages[index].content,
            createdAt: _messages[index].createdAt,
            status: event.message['status'], // ✅ Update status
          );
          print(
            "Updated message: ${_messages[index].id} ${_messages[index].content}",
          );

          // ✅ Update mappings
          tempIdMap.remove(tempId);
          _messageIndexMap.remove(tempId);
          _messageIndexMap[realId] = index; // ✅ Store real ID in map

          emit(ChatLoadedState(List.from(_messages))); // ✅ Refresh UI
        }
      }

      print("Skipping duplicate message from sender.");
      return; // ✅ Prevent adding the sender's own message again
    }

    print("Moving to step 3 - add message to list");

    final message = MessageEntity(
      id: event.message['id'],
      conversationId: event.message['conversation_id'],
      senderId: event.message['sender_id'],
      content: event.message['content'],
      createdAt: event.message['created_at'],
      status: event.message['status'],
    );

    print("Received message in chatbloc: $message");

    _messages.add(message);

   
    print("Called message delivered event");

    emit(ChatLoadedState(List.from(_messages)));
  }

  Future<void> _onMessageStatusUpdated(
    MessageStatusUpdatedEvent event,
    Emitter<ChatState> emit,
  ) async {
    print("Updating in ui " + event.messageId);
    print("Message id from local state: ${_messages[_messages.length - 1].id}");

    // ✅ Start searching from the last message (most recent)
    for (int i = _messages.length - 1; i >= 0; i--) {
      
      if (_messages[i].id.trim() == event.messageId.trim()) {
        print("Found message to update: ${_messages[i]}");
        // ✅ Create updated message with only status changed
        final updatedMessage = MessageEntity(
          id: _messages[i].id,
          conversationId: _messages[i].conversationId,
          senderId: _messages[i].senderId,
          content: _messages[i].content,
          createdAt: _messages[i].createdAt,
          status: event.status, // ✅ Update only status
        );

        // ✅ Update the message at index `i`
        _messages[i] = updatedMessage;

        // ✅ Emit new state with updated list
        emit(ChatLoadedState(List.from(_messages)));

        break; // ✅ Stop searching after updating the first match (efficiency)
      }
    }
  }


  void _onMessageSeen(MessageSeenEvent event, Emitter<ChatState> emit) {
    _socketService.markMessageSeen(event.messageId, event.conversationId);
  }

  void _onTypingStarted(
    TypingStartedEvent event,
    Emitter<ChatState> emit,
  ) async {
    String userId = await _storage.read(key: "userId") ?? '';
    _socketService.startTyping(event.conversationId, userId);
  }

  void _onTypingStopped(TypingStopped event, Emitter<ChatState> emit) async {
    String userId = await _storage.read(key: "userId") ?? '';
    _socketService.stopTyping(event.conversationId, userId);
  }
}
