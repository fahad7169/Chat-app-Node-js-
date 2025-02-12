
import 'package:chat_app/features/auth/domain/entities/user_entity.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_respository.dart';

class LoginUsecase {

  final AuthRespository repository;

  LoginUsecase({ required this.repository});
  Future<UserEntity> call(String email,String password) {
    return repository.login(email,password);
  }
}