abstract class ContactsEvent {}

class FetchContactsEvent extends ContactsEvent {}

class CheckOrCreateConversationEvent extends ContactsEvent {
  final String contactId;
  final String contactName;

  CheckOrCreateConversationEvent(this.contactId, this.contactName);
}

class AddContactEvent extends ContactsEvent {
  final String email;

  AddContactEvent({required this.email});
}
