
import 'package:chat_app/features/contacts/domain/repositories/contacts_repositories.dart';

class AddContactUsecase {
  final ContactsRepositories contactsRepositories;
  AddContactUsecase({required this.contactsRepositories});

  Future<void> call({required String email}) async{
    return await contactsRepositories.addContact(email: email);
  }
}
