import 'package:chat_app/features/contacts/domain/usecases/add_contact_usecase.dart';
import 'package:chat_app/features/contacts/domain/usecases/fetch_contacts_usecase.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_event.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_state.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final FetchContactsUsecase fetchContactsUsecase;
  final AddContactUsecase addContactUsecase;
  final CheckOrCreateConversationUseCase checkOrCreateConversationUseCase;

  ContactsBloc({
    required this.fetchContactsUsecase,
    required this.addContactUsecase,
    required this.checkOrCreateConversationUseCase,
  }) : super(ContactsInitial()) {
    on<FetchContactsEvent>(_onFetchContactsEvent);
    on<AddContactEvent>(_onAddContactEvent);
    on<CheckOrCreateConversationEvent>(_onCheckOrCreateConversationEvent);
  }

  Future<void> _onFetchContactsEvent(
    FetchContactsEvent event,
    Emitter<ContactsState> emit,
  ) async {
    emit(ContactsLoading());
    try {
      final contacts = await fetchContactsUsecase.call();
      print("Contacts: $contacts");
      emit(ContactsLoaded(contacts));
    } catch (e) {
      emit(ContactsError(e.toString()));
    }
  }

  Future<void> _onAddContactEvent(
    AddContactEvent event,
    Emitter<ContactsState> emit,
  ) async {
    emit(ContactsLoading());
    try {
      await addContactUsecase.call(email: event.email);
      emit(ContactAdded());
      add(FetchContactsEvent());
      
    } catch (e) {
      emit(ContactsError(e.toString()));
    }
  }
  
  Future <void> _onCheckOrCreateConversationEvent(
    CheckOrCreateConversationEvent event,
    Emitter<ContactsState> emit,
  ) async {
    emit(ContactsLoading());
    try {
      final conversationId = await checkOrCreateConversationUseCase.call(contactId: event.contactId);
      emit(ConversationReady(conversationId:conversationId,contactName:event.contactName));
    } catch (e) {
      emit(ContactsError(e.toString()));
    }
  }
}