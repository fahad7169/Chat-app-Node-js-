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
import 'package:collection/collection.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FetchMessagesUseCase fetchMessagesUseCase;

  final SocketService _socketService = SocketService();
  // Map for quick lookup of message index
  final Map<String, int> _messageIndexMap = {};
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
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<MessageSeenEvent>(_onMessageSeen);
    on<TypingStartedEvent>(_onTypingStarted);
    on<TypingStopped>(_onTypingStopped);
    on<MessageStatusUpdatedEvent>(_onMessageStatusUpdated);
    on<RefreshUiEvent>(_onRefreshUi);
    on<RefreshMessagesFromHiveEvent>(_onRefreshMessagesFromHive);
    _messagesBox = Hive.box<MessageEntity>('messages');
    _listenForReconnection();
    _startPeriodicResend();
  }

Future<void> _onRefreshMessagesFromHive(RefreshMessagesFromHiveEvent event, Emitter<ChatState> emit) async {
    // Reset messages when loading new conversation
    _messages.clear(); // Add this line
    _pendingMessages.clear();

    if (event.conversationId.isEmpty) {
      emit(ChatLoadedState([]));
      return;
    }


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
          emit(ChatLoadedState(List.from(_messages)));
          _pendingMessages =
              _messages.where((msg) => msg.status == 'pending').toList();
      
        }
      }
    }
    catch(e){

    }
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
      emit(ChatLoadedState([]));
      return;
    }


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
          emit(ChatLoadedState(List.from(_messages)));
          _pendingMessages =
              _messages.where((msg) => msg.status == 'pending').toList();
      
        }
      }

      // Step 2: Check if socket is connected before making API request
      if (!_socketService.socket.connected) {
        throw Exception("Socket is not connected");
      }

      // Step 3: Fetch messages from API
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

        // Step 5: Cleanup local-only messages
Set<String> fetchedIds = fetchedMessages.map((e) => e.id).toSet();
List<MessageEntity> messagesToRemove = _messages.where((msg) => !fetchedIds.contains(msg.id)).toList();

for (var msg in messagesToRemove) {
  await _messagesBox.delete(msg.id);
  _messages.removeWhere((m) => m.id == msg.id);
}

        // Sort messages again after merging
        _messages.sort(
          (a, b) => DateTime.parse(
            a.createdAt,
          ).compareTo(DateTime.parse(b.createdAt)),
        );

        emit(ChatLoadedState(List.from(_messages)));
      }
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


    _messages.add(newMessage);
    await _messagesBox.put(newMessage.id, newMessage); // Save to Hive
    _messageIndexMap[tempMessageId] = _messages.length - 1;

    emit(ChatLoadedState(List.from(_messages))); // Update UI immediately

       tempIdMap[tempMessageId] = event.content;
    
    _attemptToSendMessage(newMessage);
  }

  void _attemptToSendMessage(MessageEntity message) async {

    try {
      if (await _isConnected()) {
        String userId = await _storage.read(key: "userId") ?? '';
        MessageEntity updatedMessage = message;

        // 🔥 Re-check and create conversation if missing
        if (updatedMessage.conversationId.isEmpty) {
          final newConversationId = await _onCheckOrCreateConversationEvent(
            message.contactId,
          );

          if (newConversationId.isEmpty) {
            throw Exception("Conversation creation failed");
          }

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
          
          if (messageData['conversation_id'] == updatedMessage.conversationId &&
              messageData['sender_id'] == updatedMessage.senderId &&
              messageData['id'] != null &&
              messageData['content'] == updatedMessage.content) {
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

            add(RefreshUiEvent());

            await _messagesBox.put(finalMessage.id, finalMessage);
            await _messagesBox.delete(message.id); // Delete temp

            _messageIndexMap[finalMessage.id] = index;
            _messageIndexMap.remove(message.id); // ✅ Cleanup

            _pendingMessages.remove(message);

            //remove temp id from map
            tempIdMap.remove(message.id);


          }
        });
      } else {
        _addToPendingIfNeeded(message);
      }
    } catch (e) {
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
    return isConnected;
  }

  void _retryPendingMessages() async {
    if (await _isConnected()) {
      for (var message in List.from(_pendingMessages)) {
        _attemptToSendMessage(message);
      }
    }
  }

  void _startPeriodicResend() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      _retryPendingMessages();
    });
  }

  void _listenForReconnection() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _retryPendingMessages();
      }
    });
  }

  Future<String> _onCheckOrCreateConversationEvent(String contactId) async {
    try {
      final conversationId = await checkOrCreateConversationUseCase.call(
        contactId: contactId,
      );
      if (conversationId.isEmpty) throw Exception("Empty conversation ID");
      return conversationId;
    } catch (e) {
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

    String userId = await _storage.read(key: "userId") ?? '';

   String realId = event.message['id'];
    String content = event.message['content'];
    String senderId = event.message['sender_id'];

    try {
      // ✅ Check if this message was sent by us (we need to update temp ID)
     if (senderId == userId) {

      // Find temp message using content
      String? tempId =
          tempIdMap.entries
              .firstWhereOrNull((entry) => entry.value == content)
              ?.key;


      if (tempId != null && _messageIndexMap.containsKey(tempId)) {
        int? index = _messageIndexMap[tempId];

        if (index != null && index >= 0 && index < _messages.length) {
          // ✅ Update local state by replacing temp ID with real ID
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
          await _messagesBox.delete(tempId);
          //update message in hive
          await _messagesBox.put(realId, _messages[index]);
    
          // ✅ Update mappings
          tempIdMap.remove(tempId);
          _messageIndexMap.remove(tempId);
          _messageIndexMap[realId] = index; // ✅ Store real ID in map

          emit(ChatLoadedState(List.from(_messages))); // ✅ Refresh UI
        }
      }

      return; // ✅ Prevent adding the sender's own message again
    }


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


      // Add the new message
      _messages.add(message);

      // Sort messages by createdAt in descending order (latest first)
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Emit the updated state with the sorted messages list
      emit(ChatLoadedState(List.from(_messages)));
    } catch (e) {
    }
  }


  Future<void> _onMessageStatusUpdated(
    MessageStatusUpdatedEvent event,
    Emitter<ChatState> emit,
  ) async {

    try {
      Future<void> tryUpdateStatus({required int attempt}) async {
        // Check if the message exists in _messageIndexMap
        if (_messageIndexMap.containsKey(event.messageId.trim())) {
          int index = _messageIndexMap[event.messageId.trim()]!;

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
        
          await Future.delayed(const Duration(milliseconds: 300));
          await tryUpdateStatus(attempt: attempt + 1);
        } else {
        
        }
      }

      await tryUpdateStatus(attempt: 1);
    } catch (e) {
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


