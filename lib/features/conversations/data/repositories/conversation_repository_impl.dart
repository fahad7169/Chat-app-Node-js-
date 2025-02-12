import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';
import 'package:chat_app/features/conversations/domain/repositories/conversations_repository.dart';

class ConversationRepositoryImpl implements ConversationsRepository {
  @override
  Future<List<ConversationEntity>> fetchConversations() {
    // TODO: implement fetchConversations
    throw UnimplementedError();
  }
}