abstract class ContactsEvent {}

class FetchContactsEvent extends ContactsEvent {}

class AddContactEvent extends ContactsEvent {
  final String email;

  AddContactEvent({required this.email});
}

class RefreshContactsEvent extends ContactsEvent {}