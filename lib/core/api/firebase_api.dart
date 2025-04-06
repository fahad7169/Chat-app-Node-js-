import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:socket_io_client/socket_io_client.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  try {
    print("Handling a background message");
    print("Title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
    print("Payload: ${message.data}");

    // Initialize Hive
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);

    Hive.registerAdapter(ConversationModelAdapter());
    Hive.registerAdapter(MessageEntityAdapter());

    // Open the necessary Hive boxes
    Box<ConversationModel> conversationBox = await Hive.openBox<ConversationModel>(
      'conversations',
    );
     Box<MessageEntity> messageBox = await Hive.openBox<MessageEntity>('messages');

    final messageData = message.data;

    // Ensure messageData contains required fields before proceeding
    if (!messageData.containsKey('messageId') ||
        !messageData.containsKey('conversationId') ||
        !messageData.containsKey('content') ||
        !messageData.containsKey('created_at')) {
      print("Error: Missing required message data.");
      return;
    }

    // Create the new MessageEntity
    final newMessage = MessageEntity(
      id: messageData['messageId'],
      conversationId: messageData['conversationId'],
      senderId: messageData['senderId'],
      content: messageData['content'],
      createdAt: messageData['created_at'],
      status: 'delivered',
      contactId: '',
    );

    await messageBox.put(messageData['messageId'], newMessage);
    print("Message added");

    // Update the conversation
    var newConversation = ConversationModel(
      id: messageData['conversationId'],
      participantName: message.notification?.title ?? '',
      lastMessage: messageData['content'],
      lastMessageTime: DateTime.parse(messageData['created_at']),
      lastMessageStatus: 'delivered',
      lastMessageId: messageData['messageId'],
    );
    await conversationBox.put(messageData['conversationId'], newConversation);
    print("Conversation updated");

    // Send the "delivered" event via HTTP
    final messageId = messageData['messageId'];
    final conversationId = messageData['conversationId'];

     final SocketService _socketService = SocketService();
     await _socketService.initSocket();
    try {
   _socketService.socket.onConnect((_) {
      print("Socket connected: ${_socketService.socket.id}");
      _socketService.socket.emit("messageDelivered", {
      "messageId": messageId, // ✅ Corrected to use key-value pairs
      "conversationId": conversationId,
    });

    });
    } catch (e) {
      print("Error sending delivered event: $e");
    }
  } catch (e) {
    print("Error handling background message: $e");
  }
}

Future<void> handleForegroundMessage(RemoteMessage message) async {
  try {
        print("Handling a foreground message");
    print("Title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
    print("Payload: ${message.data}");

    Box<MessageEntity> messageBox;

    // Ensure the box is open
    if (Hive.isBoxOpen('messages')) {
      messageBox = Hive.box<MessageEntity>('messages');
    } else {
      messageBox = await Hive.openBox<MessageEntity>('messages');
    }

    final messageData = message.data;

    // Ensure messageData contains required fields before proceeding
    if (!messageData.containsKey('messageId') ||
        !messageData.containsKey('conversationId') ||
        !messageData.containsKey('content') ||
        !messageData.containsKey('created_at')) {
      print("Error: Missing required message data.");
      return;
    }

    // Create the new MessageEntity
    final newMessage = MessageEntity(
      id: messageData['messageId'],
      conversationId: messageData['conversationId'],
      senderId: messageData['senderId'],
      content: messageData['content'],
      createdAt: messageData['created_at'],
      status: 'delivered',
      contactId: '',
    );

    await messageBox.put(messageData['messageId'], newMessage);
    print("Message added");
  } catch (e) {
    print("Error handling foreground message: $e");
  }
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<void> initNotifications() async {
    try {
      // Request notification permission
      await _firebaseMessaging.requestPermission();

      // Get FCM Token and store it securely
      final fcmToken = await _firebaseMessaging.getToken();
      print("FCM Token: $fcmToken");

      if (fcmToken != null) {
        await storage.write(key: "fcmToken", value: fcmToken);
      }

      // Set background and foreground message handlers
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
      FirebaseMessaging.onMessage.listen(handleForegroundMessage);

    } catch (e) {
      print("Error initializing notifications: $e");
    }
  }
} 