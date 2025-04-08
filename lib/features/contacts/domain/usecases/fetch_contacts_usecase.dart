import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';
import 'package:chat_app/features/contacts/domain/repositories/contacts_repositories.dart';

class FetchContactsUsecase {
  final ContactsRepositories contactsRepositories;
  FetchContactsUsecase({required this.contactsRepositories});

  Future<List<ContactEntity>> call() async{
    final contacts = await contactsRepositories.fetchContacts();
    return contacts;
  }
}
