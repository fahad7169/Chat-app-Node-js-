import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';

class ContactsModel extends ContactEntity{

  

   ContactsModel({required id,required  username, required  email}):super(id: id, username: username, email: email);
 
 factory ContactsModel.fromJson(Map<String, dynamic> json) {
    return ContactsModel(
      id: json['contact_id'],
      username: json['username'],
      email: json['email'],
    );
  }
}