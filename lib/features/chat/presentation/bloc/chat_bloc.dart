import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/domain/usecases/fetch_messages_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FetchMessagesUseCase fetchMessagesUseCase;

  final SocketService _socketService = SocketService();

  final List<MessageEntity> _messages = [];
  final _storage = FlutterSecureStorage();

  ChatBloc({required this.fetchMessagesUseCase}) : super(ChatLoadingState()) {
    on<LoadMessagesEvent>(_onloadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
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

      _socketService.socket.emit('joinConversation', event.conversationId);

      _socketService.socket.on('receiveMessage', (data) {
        print("Received new message: $data");
        add(ReceiveMessageEvent(data));
      });

    } catch (e) {
      emit(ChatErrorState(e.toString()));
    }
  }
Future<void> _onSendMessage(
  SendMessageEvent event,
  Emitter<ChatState> emit,
) async {
  String userId = await _storage.read(key: "userId") ?? '';
  print("user id: $userId");

  final newMessage = MessageEntity(
    id: DateTime.now().toString(), // Temporary ID
    conversationId: event.conversationId,
    senderId: userId,
    content: event.content,
    createdAt: DateTime.now().toIso8601String(),
  );

  _messages.add(newMessage);  // ✅ Add message immediately
  emit(ChatLoadedState(List.from(_messages))); // ✅ Update UI

  final messageData = {
    'conversationId': event.conversationId,
    'content': event.content,
    'senderId': userId,
  };

  _socketService.socket.emit('sendMessage', messageData);
}


  Future<void> _onReceiveMessage(
    ReceiveMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    print("Step 2 - receive event called");
    print(event.message);

    final message = MessageEntity(
      id: event.message['id'],
      conversationId: event.message['conversation_id'],
      senderId: event.message['sender_id'],
      content: event.message['content'],
      createdAt: event.message['created_at'],
    );

    _messages.add(message);

    emit(ChatLoadedState(List.from(_messages)));
  }
}
