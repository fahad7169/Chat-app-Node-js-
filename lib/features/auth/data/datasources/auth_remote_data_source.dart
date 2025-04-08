import 'dart:convert';

import 'package:chat_app/core/constants.dart';
import 'package:chat_app/features/auth/data/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthRemoteDataSource {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    String? fcmToken = await storage.read(key: "fcmToken") ?? '';


    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      body: jsonEncode({
        'email': email,
        'password': password,
        'fcmToken': fcmToken,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    if(response.statusCode == 200){
      
    final decodedJson = jsonDecode(response.body);
    return UserModel.fromJson(decodedJson['user']);
    }
    else{
       throw Exception(response.body);
    }

  }


  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 201) {
      throw Exception(response.body);
    }

    // ✅ Return dummy data
  return UserModel(
    id: "0",
    username: username,
    email: email,
    token: "dummy_token",
  );
  }
}
