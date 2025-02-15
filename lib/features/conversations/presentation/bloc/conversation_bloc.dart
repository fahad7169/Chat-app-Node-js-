import 'package:chat_app/features/conversations/domain/usecases/fetch_conversations_use_case.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_event.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversations_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationBloc extends Bloc<ConversationsEvent, ConversationsState> {
  final FetchConversationsUseCase fetchConversationsUseCase;

  ConversationBloc({required this.fetchConversationsUseCase})
    : super(ConversationsInitial()) {
    on<FetchConversations>(_onFetchConversations);
  }

  Future<void> _onFetchConversations(
    FetchConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(ConversationsLoading());
    try {
      final conversations = await fetchConversationsUseCase();
      print("Fetched Conversations: $conversations");  // Add this line
      emit(ConversationsLoaded(conversations: conversations));
    } catch (e) {
      emit(ConversationsError("Failed to load conversations"));
    }
  }
}
