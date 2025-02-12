import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';

abstract class ConversationsRepository {
  Future<List<ConversationEntity>> fetchConversations();

}