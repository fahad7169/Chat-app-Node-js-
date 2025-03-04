import 'dart:async';

import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/domain/usecases/fetch_messages_use_case.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FetchMessagesUseCase fetchMessagesUseCase;

  final SocketService _socketService = SocketService();
  // Map for quick lookup of message index
  Map<String, int> _messageIndexMap = {};
  Map<String, String> tempIdMap = {}; // temp_id -> real_id

  List<MessageEntity> _messages = [];
  List<MessageEntity> _pendingMessages = [];
  final _storage = FlutterSecureStorage();
  Box<MessageEntity> _messagesBox = Hive.box<MessageEntity>('messages');
   final CheckOrCreateConversationUseCase checkOrCreateConversationUseCase;

  ChatBloc({required this.fetchMessagesUseCase, required this.checkOrCreateConversationUseCase,}) : super(ChatLoadingState()) {

    on<LoadMessagesEvent>(_onloadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<MessageSeenEvent>(_onMessageSeen);
    on<TypingStartedEvent>(_onTypingStarted);
    on<TypingStopped>(_onTypingStopped);
    on<MessageStatusUpdatedEvent>(_onMessageStatusUpdated);
    _messagesBox = Hive.box<MessageEntity>('messages');
    _listenForReconnection();
    _startPeriodicResend();
    _initializeSocketListeners();
  }

  /// 🔹 Initializes socket listeners
  void _initializeSocketListeners() {
    try {
      _socketService.socket.on("receiveMessage", _onMessageReceived);
    } catch (e) {
      print("❌ Error initializing socket: $e");
    }
  }

  void _onMessageReceived(dynamic data) {
    print("Received message: $data");
    add(ReceiveMessageEvent(data));
  }

  Future<void> _onloadMessages(
    LoadMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoadingState());

    try {
      if (_messagesBox.isOpen) {
        final storedMessages =
            _messagesBox.values
                .where((msg) => msg.conversationId == event.conversationId)
                .toList();

        if (storedMessages.isNotEmpty) {
          _messages = List.from(storedMessages);
          print("Messages loaded from Hive: ${_messages.length}");
          emit(ChatLoadedState(List.from(_messages)));
          _pendingMessages =
              _messages.where((msg) => msg.status == 'pending').toList();
          return;
        }
      }

      print("Messages are being loaded from API");
      final messages = await fetchMessagesUseCase.call(event.conversationId);

      _messages.addAll(messages);

      for (var message in messages) {
        await _messagesBox.put(message.id, message);
      }

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
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    final newMessage = MessageEntity(
      id: tempMessageId,
      conversationId: event.conversationId,
      senderId: userId,
      content: event.content,
      createdAt: DateTime.now().toIso8601String(),
      status: 'pending', // Initially pending
    );

    _messages.add(newMessage);
    _messagesBox.put(newMessage.id, newMessage); // Save to Hive
    _messageIndexMap[tempMessageId] = _messages.length - 1;

      // ✅ Store temp ID mapping  
    tempIdMap[tempMessageId] = event.content;
    print("Temp id is saved ${tempMessageId}");

    emit(ChatLoadedState(List.from(_messages))); // Update UI immediately

    _pendingMessages.add(newMessage);

    // Try sending the message
    _attemptToSendMessage(newMessage);
  }

  // Function to send a message
  void _attemptToSendMessage(MessageEntity message) async {
   try{
     if (await _isConnected()) {
      final messageData = {
        'conversationId': message.conversationId,
        'content': message.content,
        'senderId': message.senderId,
      };

      _socketService.socket.emit("sendMessage", messageData);
    } else {
      print("No internet. Storing message for retry.");
      _pendingMessages.add(message);
    }
   }
   catch(e){
    
   }
  }

  // Check internet connection
  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Retry unsent messages
  void _retryPendingMessages() async {
    if (await _isConnected()) {
      for (var message in List.from(_pendingMessages)) {
        _attemptToSendMessage(message);
        _pendingMessages.remove(message); // Remove after sending
      }
    }
  }

  // Periodically retry every 10 seconds (even if internet is there)
  void _startPeriodicResend() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      _retryPendingMessages();
    });
  }

  // Listen for internet reconnection
  void _listenForReconnection() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print("Internet reconnected. Retrying pending messages...");
        _retryPendingMessages();
      }
    });
  }

  
  Future<void> _onCheckOrCreateConversationEvent(contactId) async {
    try {
      final conversationId = await checkOrCreateConversationUseCase.call(
        contactId: contactId,
      );

    } catch (e) {
      print("Error creating conversation");
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
            status: 'sent', // ✅ Update status
          );

          //delete message from _pendingMessages
          _pendingMessages.removeWhere((message) => message.id == tempId);

          //delete message in hive with tempid
          _messagesBox.delete(tempId);
          //update message in hive
          print("Message updated in hive: ${_messages[index]}");
          _messagesBox.put(realId, _messages[index]);
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

    // add message to hive
    _messagesBox.put(message.id, message);

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

        // update message in hive
        _messagesBox.put(_messages[i].id, _messages[i]);

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
