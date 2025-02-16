import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';

abstract class ContactsRepositories {
  Future<List<ContactEntity>> fetchContacts();
  Future<void> addContact({required String email});

}