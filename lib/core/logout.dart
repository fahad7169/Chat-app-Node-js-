import 'dart:convert';
import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

Future<bool> logout() async {


  final SocketService _socketService = SocketService();
  if(!await _isConnected()) return false;
  final String baseUrl = 'http://192.168.122.14:6000';
  final storage = FlutterSecureStorage();

  String? userId = await storage.read(key: 'userId');

  if (userId == null) {
    print("❌ No userId found. Cannot logout.");
    return false;
  }


  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      body: jsonEncode({'userId': userId}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      print("✅ Logout API successful. Clearing data...");

       print("📴 Sending user offline...");
      _socketService.socket.emit('userOffline', {"userId": userId});

      // Remove socket listeners
      _socketService.socket.off('receiveMessage');
      _socketService.socket.off('conversationUpdated');
      _socketService.socket.off('userOnline');
      _socketService.socket.off('userOffline');
      _socketService.socket.off('typing');
      _socketService.socket.off('stopTyping');
      _socketService.socket.off('messageStatusUpdated');
      _socketService.socket.off('messageDelivered');
      _socketService.socket.off('onlineUsersList');

      
      // Clear all storage (now safe to do)
      await storage.deleteAll();

     Box<ConversationModel> _conversationBox = Hive.box<ConversationModel>(
    'conversations',
  );

  Box<MessageEntity> _messageBox = Hive.box<MessageEntity>(
    'messages',
  );

  Box<ContactEntity> _contactBox = Hive.box<ContactEntity>(
    'contacts',
  );
  

  await _conversationBox.clear();
  await _messageBox.clear();
  await _contactBox.clear();
  
      return true;
    } else {
      print("❌ Logout failed: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    print("❌ Logout error: $e");
    return false;
  }
}

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;
    print("🌐 Internet Check: ${isConnected ? 'Connected' : 'Disconnected'}");
    return isConnected;
  }
