import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:chat_app/features/conversations/domain/usecases/fetch_conversations_use_case.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_event.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversations_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConversationBloc extends Bloc<ConversationsEvent, ConversationsState> {
  final FetchConversationsUseCase fetchConversationsUseCase;
  final SocketService _socketService = SocketService();
  final _storage = const FlutterSecureStorage();

  List<ConversationModel> _conversations = []; // Store local state

  ConversationBloc({required this.fetchConversationsUseCase})
    : super(ConversationsInitial()) {
    on<FetchConversations>(_onFetchConversations);
    on<UpdateConversation>(_onUpdateConversation); // Handle socket updates
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

  /// 🔹 Fetches conversations from API and updates local state
  Future<void> _onFetchConversations(
    FetchConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(ConversationsLoading());
    try {
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

      // Get the current user ID from storage
      String userId = await _storage.read(key: "userId") ?? '';

      emit(ConversationsLoaded(conversations: List.from(_conversations)));

      // Now, for each conversation, join the conversation room via socket
      for (var conv in _conversations) {
        _socketService.socket.emit('joinConversation', {
          "conversationId": conv.id,
          "userId": userId,
        });
      }
    } catch (e) {
      emit(ConversationsError("❌ Failed to load conversations"));
    }
  }

  /// 🔹 Handles incoming socket updates and dispatches an event
  void _onConversationUpdated(data) {
    print("🔥 Socket update received: $data");
   
    
    _onMessageDelivered(data['lastMessageId'], data['conversationId']);


    print("Marking delivered event fired ");
    add(
      UpdateConversation(
        conversationId: data['conversationId'],
        lastMessage: data['lastMessage'],
        lastMessageTime: DateTime.parse(data['lastMessageTime']),
        lastMessageStatus: data['lastMessageStatus'] ?? '',
        lastMessageId: data['lastMessageId'],
      ),
    );
  }

  void _onMessageDelivered( messageId, conversationId) {
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
        id: _conversations[index].id, // Keep the same ID
        participantName:
            _conversations[index].participantName, // Keep same name
        lastMessage: event.lastMessage, // Update message
        lastMessageTime: event.lastMessageTime, // Update timestamp
        lastMessageStatus: event.lastMessageStatus,
        lastMessageId: event.lastMessageId,
      );

      emit(ConversationsLoaded(conversations: List.from(_conversations)));
      print("🚀 Updated conversation: ${_conversations[index]}");
    } else {
      print("❌ Conversation not found in list!");
    }
  }
}
