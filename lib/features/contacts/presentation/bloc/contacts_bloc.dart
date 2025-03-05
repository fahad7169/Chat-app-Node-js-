import 'package:chat_app/core/socket_service.dart';
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
   final SocketService _socketService = SocketService();

  ContactsBloc({
    required this.fetchContactsUsecase,
    required this.addContactUsecase,
    required this.checkOrCreateConversationUseCase,
  }) : super(ContactsInitial()) {
    _contactsBox = Hive.box<ContactEntity>('contacts');
    on<FetchContactsEvent>(_onFetchContactsEvent);
    on<AddContactEvent>(_onAddContactEvent);
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

      
       if (!_socketService.socket.connected) {
        print("Socket not connected");
        emit(ContactsError("Check your internet connection"));
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
      emit(ContactsLoading());
      try{

      
     if (!_socketService.socket.connected) {
        print("Socket not connected");
        emit(ContactsError("Check your internet connection"));
        return;
      }
    final contacts = await fetchContactsUsecase.call();
    // 🔥 Step 3: Save fetched conversations to Hive
    await _contactsBox.clear();
    for (var contact in contacts) {
      await _contactsBox.put(contact.id, contact);
    }
    print("Contacts: $contacts");

      }
      catch(e){
        print("Failed to refresh contacts: $e");

      }
      finally{
    emit(ContactsLoaded(_contactsBox.values.toList()));

      }
  }

  Future<void> _onAddContactEvent(
    AddContactEvent event,
    Emitter<ContactsState> emit,
  ) async {
    try {
       if (!_socketService.socket.connected) {
        print("Socket not connected");
        emit(ContactAddedError("Check your internet connection"));
        return;
      }
      await addContactUsecase.call(email: event.email);
      emit(ContactAdded());
      add(FetchContactsEvent());
    } catch (e) {
      emit(ContactAddedError(e.toString()));
    }
  }


}
