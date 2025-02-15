import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';
import 'package:chat_app/features/conversations/domain/repositories/conversations_repository.dart';

class FetchConversationsUseCase {
  final ConversationsRepository repository;

  FetchConversationsUseCase({required this.repository});

  Future<List<ConversationEntity>> call() async {
    final conversations = await repository.fetchConversations();
    print("usecase fetched conversations: $conversations"); // Add this line
    return conversations;
  }
}
