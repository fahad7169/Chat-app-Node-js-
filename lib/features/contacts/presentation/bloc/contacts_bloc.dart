import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';
import 'package:chat_app/features/contacts/domain/usecases/add_contact_usecase.dart';
import 'package:chat_app/features/contacts/domain/usecases/fetch_contacts_usecase.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_event.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_state.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final FetchContactsUsecase fetchContactsUsecase;
  final AddContactUsecase addContactUsecase;
  final CheckOrCreateConversationUseCase checkOrCreateConversationUseCase;
  Box<ContactEntity> _contactsBox = Hive.box<ContactEntity>('contacts');
  List<ContactEntity> _contacts = [];

  ContactsBloc({
    required this.fetchContactsUsecase,
    required this.addContactUsecase,
    required this.checkOrCreateConversationUseCase,
  }) : super(ContactsInitial()) {
    _contactsBox = Hive.box<ContactEntity>('contacts');
    on<FetchContactsEvent>(_onFetchContactsEvent);
    on<AddContactEvent>(_onAddContactEvent);
    on<CheckOrCreateConversationEvent>(_onCheckOrCreateConversationEvent);
    on<RefreshContactsEvent>(_onRefreshContactsEvent);
  }

  Future<void> _onFetchContactsEvent(
    FetchContactsEvent event,
    Emitter<ContactsState> emit,
  ) async {
    emit(ContactsLoading());
    try {
      if (_contactsBox.isOpen) {
        _contacts = _contactsBox.values.toList();
      } else {
        print(" Contacts box is not open");
      }

      if (_contacts.isNotEmpty) {
        print("Contacts loaded from  Hive ${_contacts.length}");
        emit(ContactsLoaded(_contacts));
        return;
      }
      print("Contacts are being loaded  from API");
      final contacts = await fetchContactsUsecase.call();
      // 🔥 Step 3: Save fetched conversations to Hive
      await _contactsBox.clear();
      for (var contact in contacts) {
        await _contactsBox.put(contact.id, contact);
      }
      print("Contacts: $contacts");
      emit(ContactsLoaded(contacts));
    } catch (e) {
      emit(ContactsError("❌ Failed to load contacts $e"));
    }
  }

  Future<void> _onRefreshContactsEvent(
    RefreshContactsEvent event,
    Emitter<ContactsState> emit,
  ) async {
    final contacts = await fetchContactsUsecase.call();
    // 🔥 Step 3: Save fetched conversations to Hive
    await _contactsBox.clear();
    for (var contact in contacts) {
      await _contactsBox.put(contact.id, contact);
    }
    print("Contacts: $contacts");
    emit(ContactsLoaded(contacts));
  }

  Future<void> _onAddContactEvent(
    AddContactEvent event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      await addContactUsecase.call(email: event.email);
      emit(ContactAdded());
      emit(ContactsLoading());
      add(FetchContactsEvent());
    } catch (e) {
      emit(ContactAddedError(e.toString()));
    }
  }

  Future<void> _onCheckOrCreateConversationEvent(
    CheckOrCreateConversationEvent event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      final conversationId = await checkOrCreateConversationUseCase.call(
        contactId: event.contactId,
      );
      emit(
        ConversationReady(
          conversationId: conversationId,
          contactName: event.contactName,
        ),
      );
    } catch (e) {
      print("Error creating conversation");
      emit(ConversationReady(conversationId: "", contactName: event.contactName));
    }
  }
}
