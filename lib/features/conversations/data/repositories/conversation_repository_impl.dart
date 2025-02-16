import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';
import 'package:chat_app/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:chat_app/features/conversations/data/datasources/conversation_remote_data_source.dart';

class ConversationRepositoryImpl implements ConversationsRepository {

  final ConversationRemoteDataSource conversationRemoteDataSource;

  ConversationRepositoryImpl({ required this.conversationRemoteDataSource });

  @override
  Future<List<ConversationEntity>> fetchConversations() async{
   return await conversationRemoteDataSource.fetchConversations();
  }
  
  @override
  Future<String> checkOrCreateConversation({required String contactId}) async{
    return await conversationRemoteDataSource.checkOrCreateConversation(contactId: contactId);
  }
}