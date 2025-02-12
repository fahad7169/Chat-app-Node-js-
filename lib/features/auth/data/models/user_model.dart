import 'package:chat_app/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  UserModel({
    required String id,
    required String username,
    required String email,
    required String token,
  }) : super(id: id, username: username, email: email,token: token);

 factory UserModel.fromJson(Map<String, dynamic> json) {
  return UserModel(
    id: json["id"]?.toString() ?? "Unknown ID", // Handle null
    username: json["username"] ?? "Unknown User",
    email: json["email"] ?? "No Email", 
    token: json["token"] ?? "No Token",
  );
}

}
