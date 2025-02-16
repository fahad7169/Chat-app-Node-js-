import 'package:chat_app/features/contacts/data/datasources/contacts_remote_data_sources.dart';
import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';
import 'package:chat_app/features/contacts/domain/repositories/contacts_repositories.dart';

class ContactsRepositoryImpl implements ContactsRepositories {

  final ContactsRemoteDataSources remoteDataSources;


  ContactsRepositoryImpl({required this.remoteDataSources});


  @override
  Future<void> addContact({required String email}) async{
    return await remoteDataSources.addContact(email: email);
  }

  @override
  Future<List<ContactEntity>> fetchContacts() async {
    return await remoteDataSources.fetchContacts();
  }
  
}