import 'package:chat_app/features/chat/data/datasources/messages_remote_data_source.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/message_repository.dart';

class MessageRepositoryImpl implements MessageRepository {

  final MessagesRemoteDataSource remoteDataSource;


  MessageRepositoryImpl({required this.remoteDataSource});



  @override
  Future<List<MessageEntity>> fetchMessages(String conversationId) async{
    return await remoteDataSource.fetchMessages(conversationId);
  }

  @override
  Future<void> sendMessage(MessageEntity message) {
    // TODO: implement sendMessage
    throw UnimplementedError();
  }

  

}