
import 'package:chat_app/features/auth/domain/entities/user_entity.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_respository.dart';

class RegisterUsecase {

  final AuthRespository repository;

  RegisterUsecase({ required this.repository});
  Future<UserEntity> call(String username,String email,String password) {
    return repository.register(username,email,password);
  }
}