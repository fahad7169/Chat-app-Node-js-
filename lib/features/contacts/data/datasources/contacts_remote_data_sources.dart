import 'dart:convert';

import 'package:chat_app/features/contacts/data/models/contacts_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ContactsRemoteDataSources {
    final String baseUrl = 'http://192.168.122.14:6000';
    final _storage = FlutterSecureStorage();


    Future<List<ContactsModel>> fetchContacts() async {
      String? token = await _storage.read(key: "token");

      final response = await http.get(
        Uri.parse('$baseUrl/contacts'), 
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token"
          });


      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
       print("Remote data source fetched contacts: $data");
        return data.map((e) => ContactsModel.fromJson(e)).toList();
      } else {
        throw Exception(response.body);
      }
    }

    Future<void> addContact({required String email}) async {
      String? token = await _storage.read(key: "token");

      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        body: jsonEncode({'contactEmail': email}),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token"
        },
      );

      if (response.statusCode == 201) {
        return;
      } else {
        throw Exception(response.body);
      }
    }
}