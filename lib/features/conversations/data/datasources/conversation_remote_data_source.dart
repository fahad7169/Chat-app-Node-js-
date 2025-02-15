import 'dart:convert';

import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ConversationRemoteDataSource {
  final String baseUrl = 'http://192.168.176.14:6040';

  final _storage = FlutterSecureStorage();

  Future<List<ConversationEntity>> fetchConversations() async {
    // String token = await _storage.read(key: "token") ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjU2ZjhmNjYyLTA2OTktNGYyMC05NzJhLTJjNzNiMDM0ZjE0YiIsImlhdCI6MTczOTU5MzA2NywiZXhwIjoxNzM5NjI5MDY3fQ.j4XdDQAfeAqArL7C0veI6ELDGLdofabvQKi6Ohw-zaE',
      },
    );

    // print(response.body);

    if (response.statusCode == 200) {
     final decodedJson = jsonDecode(response.body);
List data = decodedJson["conversations"];  // ✅ Extract the list
print(data);
return data.map((e) => ConversationModel.fromJson(e)).toList();
    } else {
      throw Exception(response.body);
    }
  }
}
