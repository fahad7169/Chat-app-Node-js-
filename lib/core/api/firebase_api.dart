import 'dart:convert';

import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print("Handling a background message");
  print("Title: ${message.notification?.title}");
  print("Body: ${message.notification?.body}");
  print("Payload: ${message.data}");


  //Initialize hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

  Hive.registerAdapter(
    ConversationModelAdapter(),
  ); // ✅ Register the correct adapter
  Hive.registerAdapter(MessageEntityAdapter());

  var conversationBox = await Hive.openBox<ConversationModel>(
    'conversations',
  ); // ✅ Open with the correct type
  var messageBox = await Hive.openBox<MessageEntity>('messages');

  final messageData = message.data;

  final newMessage = MessageEntity(
    id: messageData['messageId'],
    conversationId: messageData['conversationId'],
    senderId: messageData['senderId'],
    content: messageData['content'],
    createdAt: messageData['created_at'],
    status: 'delivered',
    contactId: '',
  );

  await messageBox.put(newMessage.id, newMessage);
  print("Message added");

  //Upddate conversation
  var newConversation = ConversationModel(
    id: messageData['conversationId'],
    participantName: message.notification?.title ?? '', 
    lastMessage: messageData['content'],
    lastMessageTime: DateTime.parse(messageData['created_at']),
    lastMessageStatus: 'delivered',
    lastMessageId: messageData['messageId'],
  );
  await conversationBox.put(newConversation.id, newConversation);
  print("Conversation updated");
  //Call the api to send delivered event

  final messageId = messageData['messageId'];
  final conversationId = messageData['conversationId'];

  final String baseUrl = 'http://192.168.122.14:6000';
  //Create a http client
  http.Client client = http.Client();
  await client.post(
    Uri.parse('$baseUrl/messages/delivered'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "messageId": messageId,
      "conversationId": conversationId,
    }),
  );
  print("Delivered event sent");
}



Future<void> handleForegroundMessage(RemoteMessage message) async {
  

  Box<MessageEntity> messageBox;

  if(Hive.isBoxOpen('messages')) {
    
 messageBox =  Hive.box<MessageEntity>('messages');
  }
  else {
    messageBox = await Hive.openBox<MessageEntity>('messages');
  }


  

  final messageData = message.data;

  final newMessage = MessageEntity(
    id: messageData['messageId'],
    conversationId: messageData['conversationId'],
    senderId: messageData['senderId'],
    content: messageData['content'],
    createdAt: messageData['created_at'],
    status: 'delivered',
    contactId: '',
  );

  await messageBox.put(newMessage.id, newMessage);
  print("Message added");


}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();

    final fcmToken = await _firebaseMessaging.getToken();
    print("FCM Token: $fcmToken");
    if (fcmToken != null) {
      await storage.write(key: "fcmToken", value: fcmToken);
    }

    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    FirebaseMessaging.onMessage.listen(handleForegroundMessage);
  }
}
