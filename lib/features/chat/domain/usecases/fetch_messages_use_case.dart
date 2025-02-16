import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/message_repository.dart';

class FetchMessagesUseCase {
  final MessageRepository messageRepository;

  FetchMessagesUseCase({ required this.messageRepository});

  Future<List<MessageEntity>> call(String conversationId) async {
    return await messageRepository.fetchMessages(conversationId);
  }
}
