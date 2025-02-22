import 'dart:convert';

import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ConversationRemoteDataSource {
  final String baseUrl = 'http://192.168.122.14:6000';

  final _storage = FlutterSecureStorage();

  Future<List<ConversationEntity>> fetchConversations() async {
    String token = await _storage.read(key: "token") ?? '';

    print("Flutter token: $token");
    final response = await http.get(
      Uri.parse('$baseUrl/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("Conversations response: ${response.body}"); // Add this line to print response.body);

    if (response.statusCode == 200) {
      final decodedJson = jsonDecode(response.body);
      List data = decodedJson["conversations"]; // ✅ Extract the list
      print("Flutter data: $data");
      return data.map((e) => ConversationModel.fromJson(e)).toList();
    } else {
      throw Exception(response.body);
    }
  }

  Future<String> checkOrCreateConversation({required String contactId}) async {
    String token = await _storage.read(key: "token") ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/conversations/check-or-create'),
      body: jsonEncode({'contactId': contactId}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final decodedJson = jsonDecode(response.body);
      return decodedJson["conversationId"];
    } else {
      throw Exception(response.body);
    }
  }
}
