import 'dart:convert';

import 'package:chat_app/features/chat/data/models/message_model.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MessagesRemoteDataSource {
  final String baseUrl = 'http://192.168.122.14:6000';

  final _storage = FlutterSecureStorage();

  Future<List<MessageEntity>> fetchMessages(String conversationId) async {
    String token = await _storage.read(key: "token") ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/messages/$conversationId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((e) => MessageModel.fromJson(e)).toList();
    } else {
      throw Exception(response.body);
    }
  }
}