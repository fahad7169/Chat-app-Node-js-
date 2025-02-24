import 'package:hive/hive.dart';


part 'contact_entity.g.dart'; // ✅ Make sure this matches your filename

@HiveType(typeId: 1) // ✅ Register a unique typeId for the model
class ContactEntity {
   @HiveField(6)  
  final String id;

  @HiveField(7)
   final String username;

  @HiveField(8)
   final String email;

  ContactEntity({required this.id, required this.username, required this.email});
}
