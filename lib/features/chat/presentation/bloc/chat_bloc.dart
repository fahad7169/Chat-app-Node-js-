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

  ChatBloc({
    required this.fetchMessagesUseCase,
    required this.checkOrCreateConversationUseCase,
  }) : super(ChatLoadingState()) {
    on<LoadMessagesEvent>(_onloadMessages);
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

    if (event.conversationId.isEmpty) {
      //it is new conversation return empty list
      print("It is new conversation return empty list");
      emit(ChatLoadedState([]));
      return;
    }

    try {
      if (_messagesBox.isOpen) {
        final storedMessages =
            _messagesBox.values
                .where((msg) => msg.conversationId == event.conversationId)
                .toList();

        // 🔥 Sort messages by createdAt in ASCENDING order
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

      if (!_socketService.socket.connected) {
        print("Socket is not connected, trying to reconnect...");
        throw Exception("Socket is not connected");
    
      }

      print("Fetching messages from API...");
      final messages = await fetchMessagesUseCase.call(event.conversationId);

      // 🛑 Ensure no duplicates before adding to local storage
      Set<String> existingMessageIds =
          _messages.map((msg) => msg.id).toSet(); // Store existing message IDs

      for (var message in messages) {
        if (!existingMessageIds.contains(message.id)) {
          // Only add if it's a new message
          await _messagesBox.put(message.id, message);
          _messages.add(message); // Add to local list as well
        }
      }

      // 🔥 Sort again after adding new messages
      _messages.sort(
        (a, b) =>
            DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt)),
      );

      print("Total messages after API fetch: ${_messages.length}");
      emit(ChatLoadedState(List.from(_messages)));
    } catch (e) {
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
    _messagesBox.put(newMessage.id, newMessage); // Save to Hive
    _messageIndexMap[tempMessageId] = _messages.length - 1;

    tempIdMap[tempMessageId] = event.content;
    print("✅ Temp ID saved: ${tempIdMap[tempMessageId]}");

    emit(ChatLoadedState(List.from(_messages))); // Update UI immediately

    _attemptToSendMessage(newMessage);
  }

  void _attemptToSendMessage(MessageEntity message) async {
    print("🟡 Attempting to send message: ${message.content}");

    try {
      if (await _isConnected()) {
        String userId = await _storage.read(key: "userId") ?? '';
        MessageEntity updatedMessage = message;

        // 🔥 Always check for conversation ID on retry
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
            createdAt: DateTime.now().toIso8601String(),
            status: 'pending',
            contactId: message.contactId,
          );

          // Update local state and Hive
          final index = _messageIndexMap[updatedMessage.id]!;
          _messages[index] = updatedMessage;
          _messagesBox.put(updatedMessage.id, updatedMessage);
        }

        final messageData = {
          'conversationId': updatedMessage.conversationId,
          'content': updatedMessage.content,
          'senderId': updatedMessage.senderId,
        };

        if (!_socketService.socket.connected) {
          throw Exception("Socket is not connected");
        }

        _socketService.socket.emit("sendMessage", messageData);

        // Update status only after successful emission
        updatedMessage = updatedMessage.copyWith(status: 'sent');
        _messagesBox.put(updatedMessage.id, updatedMessage);
        _messages[_messageIndexMap[updatedMessage.id]!] = updatedMessage;
        add(RefreshUiEvent());
        _pendingMessages.remove(message);
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
            status: _messages[index].status, // ✅ Update status
            contactId: _messages[index].contactId,
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
      contactId: '',
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
          contactId: _messages[i].contactId,
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
