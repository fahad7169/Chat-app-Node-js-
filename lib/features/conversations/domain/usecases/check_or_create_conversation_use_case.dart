import 'package:chat_app/features/conversations/domain/repositories/conversations_repository.dart';

class CheckOrCreateConversationUseCase {
  final ConversationsRepository conversationsRepository;

  CheckOrCreateConversationUseCase({required this.conversationsRepository});

  Future<String> call({required String contactId}) async {
    return await conversationsRepository.checkOrCreateConversation(contactId: contactId);
  }
}
