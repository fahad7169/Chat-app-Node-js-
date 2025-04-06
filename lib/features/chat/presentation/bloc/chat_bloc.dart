import 'dart:async';

import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/domain/usecases/fetch_messages_use_case.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FetchMessagesUseCase fetchMessagesUseCase;

  final SocketService _socketService = SocketService();
  // Map for quick lookup of message index
  final Map<String, int> _messageIndexMap = {};

  List<MessageEntity> _messages = [];
  List<MessageEntity> _pendingMessages = [];
  final _storage = FlutterSecureStorage();
  Box<MessageEntity> _messagesBox = Hive.box<MessageEntity>('messages');
  final CheckOrCreateConversationUseCase checkOrCreateConversationUseCase;

  ChatBloc({
    required this.fetchMessagesUseCase,
    required this.checkOrCreateConversationUseCase,
  }) : super(ChatLoadingState()) {
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<MessageSeenEvent>(_onMessageSeen);
    on<TypingStartedEvent>(_onTypingStarted);
    on<TypingStopped>(_onTypingStopped);
    on<MessageStatusUpdatedEvent>(_onMessageStatusUpdated);
    on<RefreshUiEvent>(_onRefreshUi);
    _messagesBox = Hive.box<MessageEntity>('messages');
    _listenForReconnection();
    _startPeriodicResend();
  }

 

  Future<void> _onLoadMessages(
    LoadMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoadingState());
    // Reset messages when loading new conversation
    _messages.clear(); // Add this line
    _pendingMessages.clear();

    if (event.conversationId.isEmpty) {
      print("It is a new conversation, returning empty list");
      emit(ChatLoadedState([]));
      return;
    }

    print("Loading messages for conversation: ${event.conversationId}");

    try {
      // Step 1: Load messages from Hive if available
      List<MessageEntity> storedMessages = [];
      if (Hive.isBoxOpen('messages')) {
        storedMessages =
            _messagesBox.values
                .where((msg) => msg.conversationId == event.conversationId)
                .toList();

        // Sort messages by createdAt in ASCENDING order
        storedMessages.sort(
          (a, b) => DateTime.parse(
            a.createdAt,
          ).compareTo(DateTime.parse(b.createdAt)),
        );

        if (storedMessages.isNotEmpty) {
          _messages = List.from(storedMessages);
          print("Messages loaded from Hive (sorted): ${_messages.length}");
          emit(ChatLoadedState(List.from(_messages)));
          _pendingMessages =
              _messages.where((msg) => msg.status == 'pending').toList();
      
        }
      }

      // Step 2: Check if socket is connected before making API request
      if (!_socketService.socket.connected) {
        print("Socket is not connected, trying to reconnect...");
        throw Exception("Socket is not connected");
      }

      // Step 3: Fetch messages from API
      print("Fetching messages from API...");
      final List<MessageEntity> fetchedMessages = await fetchMessagesUseCase
          .call(event.conversationId);

      // Step 4: Process fetched messages
      if (fetchedMessages.isNotEmpty) {
        Map<String, MessageEntity> messagesMap = {
          for (var msg in _messages) msg.id: msg,
        }; // Store existing messages in a map

        for (var message in fetchedMessages) {
          if (!messagesMap.containsKey(message.id)) {
            // Case A: Add new message
            await _messagesBox.put(message.id, message);
            _messages.add(message);
          } else {
            // Case B: Update status if changed
            var existingMessage = messagesMap[message.id]!;
            if (existingMessage.status != message.status) {
              int index = _messages.indexWhere((msg) => msg.id == message.id);
              if (index != -1) {
                _messages[index] = message; // Replace the entire object
                await _messagesBox.put(message.id, message);
              }
            }
          }
        }

        // Sort messages again after merging
        _messages.sort(
          (a, b) => DateTime.parse(
            a.createdAt,
          ).compareTo(DateTime.parse(b.createdAt)),
        );

        print("Total messages after API fetch: ${_messages.length}");
        emit(ChatLoadedState(List.from(_messages)));
      }
    } catch (e) {
      print("Error loading messages: $e");

      if (_messages.isNotEmpty) {
        emit(ChatLoadedState(List.from(_messages)));
        return;
      }

      emit(ChatErrorState("Error loading messages"));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    print("🔵 _onSendMessage triggered with content: ${event.content}");

    String userId = await _storage.read(key: "userId") ?? '';
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    final newMessage = MessageEntity(
      id: tempMessageId,
      conversationId: event.conversationId,
      senderId: userId,
      content: event.content,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      status: 'pending', // Initially pending
      contactId: event.contactId,
    );

    print("🟢 New message created with temp ID: $tempMessageId");

    _messages.add(newMessage);
    await _messagesBox.put(newMessage.id, newMessage); // Save to Hive
    _messageIndexMap[tempMessageId] = _messages.length - 1;

    emit(ChatLoadedState(List.from(_messages))); // Update UI immediately

    _attemptToSendMessage(newMessage);
  }

  void _attemptToSendMessage(MessageEntity message) async {
    print("🟡 Attempting to send message: ${message.content}");

    try {
      if (await _isConnected()) {
        String userId = await _storage.read(key: "userId") ?? '';
        MessageEntity updatedMessage = message;

        // 🔥 Re-check and create conversation if missing
        if (updatedMessage.conversationId.isEmpty) {
          print("🔍 Re-attempting conversation creation...");
          final newConversationId = await _onCheckOrCreateConversationEvent(
            message.contactId,
          );

          if (newConversationId.isEmpty) {
            print("❌ Conversation creation failed. Keeping in pending.");
            throw Exception("Conversation creation failed");
          }

          print("✅ New conversation ID obtained: $newConversationId");
          updatedMessage = MessageEntity(
            id: message.id,
            conversationId: newConversationId,
            senderId: userId,
            content: message.content,
            createdAt: message.createdAt,
            status: 'pending',
            contactId: message.contactId,
          );

          final index = _messageIndexMap[updatedMessage.id]!;
          _messages[index] = updatedMessage;
          await _messagesBox.put(updatedMessage.id, updatedMessage);
        }

        final messageData = {
          'conversationId': updatedMessage.conversationId,
          'content': updatedMessage.content,
          'senderId': updatedMessage.senderId,
        };

        if (!_socketService.socket.connected) {
          throw Exception("Socket is not connected");
        }

        _socketService.socket.emit('sendMessage', messageData);

        //update fields and ui
        updatedMessage = updatedMessage.copyWith(status: 'sent');

        final index = _messageIndexMap[updatedMessage.id]!;
        _messages[index] = updatedMessage;
        await _messagesBox.put(updatedMessage.id, updatedMessage);
        add(RefreshUiEvent());

        // 🚨 Move Hive update inside socket listener
        _socketService.socket.once("updatedMessage", (messageData) async {
          print("🟢 Message updated: $messageData");
          if (messageData['conversation_id'] == updatedMessage.conversationId &&
              messageData['sender_id'] == updatedMessage.senderId &&
              messageData['id'] != null &&
              messageData['content'] == updatedMessage.content) {
            print("We got the updated message");
            final finalMessage = MessageEntity(
              id: messageData['id'],
              conversationId: messageData['conversation_id'],
              senderId: messageData['sender_id'],
              content: messageData['content'],
              createdAt: messageData['created_at'],
              status: messageData['status'],
              contactId: message.contactId,
            );

            final index = _messageIndexMap[message.id]!;

            _messages[index] = finalMessage;

            await _messagesBox.put(finalMessage.id, finalMessage);
            await _messagesBox.delete(message.id); // Delete temp

            _messageIndexMap[finalMessage.id] = index;
            _messageIndexMap.remove(message.id); // ✅ Cleanup

            add(RefreshUiEvent());
            _pendingMessages.remove(message);

            print("✅ Message successfully updated and synced");
          }
        });
      } else {
        print("⚠️ No internet. Keeping message pending.");
        _addToPendingIfNeeded(message);
      }
    } catch (e) {
      print("❌ Error sending message: $e");
      _addToPendingIfNeeded(message);
    }
  }

  void _addToPendingIfNeeded(MessageEntity message) {
    if (!_pendingMessages.any((m) => m.id == message.id)) {
      _pendingMessages.add(message);
    }
  }

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;
    print("🌐 Internet Check: ${isConnected ? 'Connected' : 'Disconnected'}");
    return isConnected;
  }

  void _retryPendingMessages() async {
    print("🔄 Retrying pending messages...");
    if (await _isConnected()) {
      for (var message in List.from(_pendingMessages)) {
        print("♻️ Retrying message: ${message.content}");
        _attemptToSendMessage(message);
      }
    }
  }

  void _startPeriodicResend() {
    print("⏳ Starting periodic resend every 10 seconds...");
    Timer.periodic(Duration(seconds: 10), (timer) {
      _retryPendingMessages();
    });
  }

  void _listenForReconnection() {
    print("🔊 Listening for reconnection...");
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print("✅ Internet reconnected! Retrying pending messages...");
        _retryPendingMessages();
      }
    });
  }

  Future<String> _onCheckOrCreateConversationEvent(String contactId) async {
    print("🔍 Checking or creating conversation...");
    try {
      final conversationId = await checkOrCreateConversationUseCase.call(
        contactId: contactId,
      );
      if (conversationId.isEmpty) throw Exception("Empty conversation ID");
      return conversationId;
    } catch (e) {
      print("❌ Critical error creating conversation: $e");
      rethrow; // Propagate error to caller
    }
  }

  Future<void> _onRefreshUi(
    RefreshUiEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoadedState(List.from(_messages)));
  }

  Future<void> _onReceiveMessage(
    ReceiveMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    print("Step 2 - receive event called");
    print(event.message);

    String userId = await _storage.read(key: "userId") ?? '';
    String senderId = event.message['sender_id'];

    try {
      // ✅ Check if this message was sent by us (we need to update temp ID)
      if (senderId == userId) {
        print("Skipping duplicate message from sender.");
        return; // ✅ Prevent adding the sender's own message again
      }

      print("Moving to step 3 - add message to list");

      //Check if this message exists in map
      

      final message = MessageEntity(
        id: event.message['id'],
        conversationId: event.message['conversation_id'],
        senderId: event.message['sender_id'],
        content: event.message['content'],
        createdAt: event.message['created_at'],
        status: event.message['status'],
        contactId: '',
      );

      print("Received message in chatbloc: $message");

      // Add the new message
      _messages.add(message);

      // Sort messages by createdAt in descending order (latest first)
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Emit the updated state with the sorted messages list
      emit(ChatLoadedState(List.from(_messages)));
    } catch (e) {
      print("Error in receive message: $e");
    }
  }


  Future<void> _onMessageStatusUpdated(
    MessageStatusUpdatedEvent event,
    Emitter<ChatState> emit,
  ) async {
    print("Updating in UI ${event.messageId}");

    try {
      Future<void> tryUpdateStatus({required int attempt}) async {
        // Check if the message exists in _messageIndexMap
        if (_messageIndexMap.containsKey(event.messageId.trim())) {
          int index = _messageIndexMap[event.messageId.trim()]!;
          print("✅ Found message to update at index: $index");

          // Update the message status
          final updatedMessage = MessageEntity(
            id: _messages[index].id,
            conversationId: _messages[index].conversationId,
            senderId: _messages[index].senderId,
            content: _messages[index].content,
            createdAt: _messages[index].createdAt,
            status: event.status,
            contactId: _messages[index].contactId,
          );

          _messages[index] = updatedMessage;

          // Update Hive and emit the new state
          await _messagesBox.put(_messages[index].id, _messages[index]);
          emit(ChatLoadedState(List.from(_messages)));
          return;
        }

        // If not found in the map, fall back to searching the list
        for (int i = _messages.length - 1; i >= 0; i--) {
          if (_messages[i].id.trim() == event.messageId.trim()) {
            print("✅ Found message to update: ${_messages[i]}");

            final updatedMessage = MessageEntity(
              id: _messages[i].id,
              conversationId: _messages[i].conversationId,
              senderId: _messages[i].senderId,
              content: _messages[i].content,
              createdAt: _messages[i].createdAt,
              status: event.status,
              contactId: _messages[i].contactId,
            );

            _messages[i] = updatedMessage;

            // Update Hive and emit the new state
            await _messagesBox.put(_messages[i].id, _messages[i]);
            emit(ChatLoadedState(List.from(_messages)));
            return;
          }
        }

        // Retry logic if the message is not found
        if (attempt < 2) {
          print(
            "⚠️ Message not found. Retrying in 300ms... (attempt $attempt)",
          );
          await Future.delayed(const Duration(milliseconds: 300));
          await tryUpdateStatus(attempt: attempt + 1);
        } else {
          print(
            "❌ Failed to update message status. Message not found after retries: ${event.messageId}",
          );
        }
      }

      await tryUpdateStatus(attempt: 1);
    } catch (e) {
      print("Error Updating status: $e");
    }
  }

  void _onMessageSeen(MessageSeenEvent event, Emitter<ChatState> emit) async {
    try {
      // Prevent duplicate processing
      final messageIndex = _messages.indexWhere((m) => m.id == event.messageId);
      if (messageIndex == -1 || _messages[messageIndex].status == 'seen')
        return;

      // Update local state
      final updatedMessage = _messages[messageIndex].copyWith(status: 'seen');
      _messages[messageIndex] = updatedMessage;

      // Update Hive
      await _messagesBox.put(updatedMessage.id, updatedMessage);

      // Notify backend via socket
      _socketService.markMessageSeen(event.messageId, event.conversationId);

      // Emit new state
      emit(ChatLoadedState(List.from(_messages)));
    } catch (e) {
      print('Error marking message seen: $e');
    }
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
