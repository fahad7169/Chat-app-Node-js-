import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:chat_app/features/conversations/domain/usecases/fetch_conversations_use_case.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_event.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversations_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class ConversationBloc extends Bloc<ConversationsEvent, ConversationsState> {
  final FetchConversationsUseCase fetchConversationsUseCase;
  final SocketService _socketService = SocketService();
  final _storage = const FlutterSecureStorage();
  Box<ConversationModel> _conversationBox = Hive.box<ConversationModel>(
    'conversations',
  );

  List<ConversationModel> _conversations = []; // Store local state

  ConversationBloc({required this.fetchConversationsUseCase})
    : super(ConversationsInitial()) {
    _conversationBox = Hive.box<ConversationModel>(
      'conversations',
    ); // ✅ Use pre-initialized Hive box
    on<FetchConversations>(_onFetchConversations);
    on<UpdateConversation>(_onUpdateConversation); // Handle socket updates
    on<RefreshConversations>(_onRefreshConversations);
    _initializeSocketListeners();
  }

  /// 🔹 Initializes socket listeners
  void _initializeSocketListeners() {
    try {
      _socketService.socket.on('conversationUpdated', _onConversationUpdated);
    } catch (e) {
      print("❌ Error initializing socket: $e");
    }
  }

  /// 🔹 Fetches conversations from API and updates local state in ascending order
  Future<void> _onFetchConversations(
    FetchConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(ConversationsLoading());

    try {
      // 🔥 Step 1: Load conversations from Hive first (instant UI update)
      if (_conversationBox.isOpen) {
        _conversations = _conversationBox.values.toList();
      } else {
        print("Hive box not opened");
      }
      if (_conversations.isNotEmpty) {
        print("Conversations loaded from Hive: ${_conversations.length}");
        emit(ConversationsLoaded(conversations: List.from(_conversations)));
        return;
      }
      print("No conversations found in Hive Loading from API");

      // 🔥 Step 2: Fetch updated conversations from API
      final conversations = await fetchConversationsUseCase();
      _conversations =
          conversations
              .map(
                (c) => ConversationModel(
                  id: c.id,
                  participantName: c.participantName,
                  lastMessage: c.lastMessage,
                  lastMessageTime: c.lastMessageTime,
                  lastMessageStatus: c.lastMessageStatus,
                  lastMessageId: c.lastMessageId,
                ),
              )
              .toList();

      // Sort conversations by latest messages first
      _conversations.sort(
        (a, b) => (b.lastMessageTime ?? DateTime(1970, 1, 1)).compareTo(
          a.lastMessageTime ?? DateTime(1970, 1, 1),
        ),
      );

      // 🔥 Step 3: Save fetched conversations to Hive
      await _conversationBox.clear(); // Clear old data
      for (var conversation in _conversations) {
        await _conversationBox.put(conversation.id, conversation);
      }
      print("Conversations saved to Hive: ${_conversations.length}");

      emit(ConversationsLoaded(conversations: List.from(_conversations)));

      // 🔥 Step 4: Join conversation rooms via socket
      String userId = await _storage.read(key: "userId") ?? '';
      for (var conv in _conversations) {
        _socketService.socket.emit('joinConversation', {
          "conversationId": conv.id,
          "userId": userId,
        });
      }
    } catch (e) {
      emit(ConversationsError("❌ Failed to load conversations $e"));
    }
  }

  Future<void> _onRefreshConversations(
    RefreshConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(ConversationsLoading());
    // 🔥 Step 2: Fetch updated conversations from API
    try{
    final conversations = await fetchConversationsUseCase();
    _conversations.clear();
    _conversations =
        conversations
            .map(
              (c) => ConversationModel(
                id: c.id,
                participantName: c.participantName,
                lastMessage: c.lastMessage,
                lastMessageTime: c.lastMessageTime,
                lastMessageStatus: c.lastMessageStatus,
                lastMessageId: c.lastMessageId,
              ),
            )
            .toList();

    // Sort conversations by latest messages first
    _conversations.sort(
      (a, b) => (b.lastMessageTime ?? DateTime(1970, 1, 1)).compareTo(
        a.lastMessageTime ?? DateTime(1970, 1, 1),
      ),
    );

    // 🔥 Step 3: Save fetched conversations to Hive
    await _conversationBox.clear(); // Clear old data
    for (var conversation in _conversations) {
      await _conversationBox.put(conversation.id, conversation);
    }
    print("Conversations saved to Hive: ${_conversations.length}");

    emit(ConversationsLoaded(conversations: List.from(_conversations)));

    // 🔥 Step 4: Join conversation rooms via socket
    String userId = await _storage.read(key: "userId") ?? '';
    for (var conv in _conversations) {
      _socketService.socket.emit('joinConversation', {
        "conversationId": conv.id,
        "userId": userId,
      });
    }
    }
    catch(e){
      emit(ConversationsError("❌ Failed to load conversations $e"));
    }
  }

  /// 🔹 Handles incoming socket updates and dispatches an event
  void _onConversationUpdated(data) async {
    print("🔥 Socket update received: $data");

    // Get the current user ID from storage
    String userId = await _storage.read(key: "userId") ?? '';

    if (data['senderId'] != userId) {
      _onMessageDelivered(data['lastMessageId'], data['conversationId']);
    }

    print("Marking delivered event fired ");
    add(
      UpdateConversation(
        conversationId: data['conversationId'],
        lastMessage: data['lastMessage'],
        lastMessageTime: DateTime.parse(data['lastMessageTime']),
        lastMessageStatus: data['lastMessageStatus'] ?? '',
        lastMessageId: data['lastMessageId'],
        participantName: data['participantName'],
      ),
    );
  }

  void _onMessageDelivered(messageId, conversationId) {
    print(
      "Emitting for marking message delivered: ${messageId} ${conversationId}",
    );
    _socketService.markMessageDelivered(messageId, conversationId);
  }

  /// 🔹 Updates only the changed conversation locally (without refetching)
  void _onUpdateConversation(
    UpdateConversation event,
    Emitter<ConversationsState> emit,
  ) {
    int index = _conversations.indexWhere((c) => c.id == event.conversationId);

    if (index != -1) {
      print("✅ Found conversation at index: $index");

      _conversations[index] = ConversationModel(
        id: _conversations[index].id, // Keep same ID
        participantName:
            _conversations[index].participantName, // Keep same name
        lastMessage: event.lastMessage, // Update message
        lastMessageTime: event.lastMessageTime, // Update timestamp
        lastMessageStatus: event.lastMessageStatus,
        lastMessageId: event.lastMessageId,
      );

      // 🔥 Save updated conversation to Hive
      _conversationBox.put(_conversations[index].id, _conversations[index]);

      // ✅ Sort the list again
      _conversations.sort(
        (a, b) => (b.lastMessageTime ?? DateTime(1970, 1, 1)).compareTo(
          a.lastMessageTime ?? DateTime(1970, 1, 1),
        ),
      );
    } else {
      print("❌ Conversation not found in list! Adding new...");

      // Add new conversation
      var newConversation = ConversationModel(
        id: event.conversationId,
        participantName: event.participantName,
        lastMessage: event.lastMessage,
        lastMessageTime: event.lastMessageTime,
        lastMessageStatus: event.lastMessageStatus,
        lastMessageId: event.lastMessageId,
      );

      _conversations.add(newConversation);

      // 🔥 Save new conversation to Hive
      _conversationBox.put(event.conversationId, newConversation);

      // ✅ Sort the list again
      _conversations.sort(
        (a, b) => (b.lastMessageTime ?? DateTime(1970, 1, 1)).compareTo(
          a.lastMessageTime ?? DateTime(1970, 1, 1),
        ),
      );
    }

    emit(ConversationsLoaded(conversations: List.from(_conversations)));
  }
}
