import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';

abstract class ContactsState {}

class ContactsInitial extends ContactsState {}

class ContactsLoading extends ContactsState {}

class ContactsLoaded extends ContactsState {
  final List<ContactEntity> contacts;
  ContactsLoaded(this.contacts);
}

class ContactsError extends ContactsState {
  final String message;

  ContactsError(this.message);
}



class ContactAdded extends ContactsState {}

class ContactAddedError extends ContactsState {
  final String message;

  ContactAddedError(this.message);
}

class ConversationReady extends ContactsState {
  final String conversationId;
  final String contactName;
  final String contactId;
  ConversationReady({
    required this.conversationId,
    required this.contactName,
    required this.contactId,
  });
}
