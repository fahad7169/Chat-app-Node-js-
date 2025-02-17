import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  late IO.Socket _socket;
  final _storage = FlutterSecureStorage();

  SocketService._internal() {
    initSocket();
  }

  Future<void> initSocket() async {
    String token = await _storage.read(key: "token") ?? '';

    _socket = IO.io(
      'http://192.168.176.14:6000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      print("Socket connected: ${_socket.id}");
    });

    _socket.onDisconnect((_) {
      print("Socket disconnected");
    });

    _socket.onConnectError((data) => print("Socket connection error: $data"));

  }

  void markMessageDelivered(String messageId) {
    socket.emit("messageDelivered", messageId);
  }

  void markMessageSeen(String messageId) {
    socket.emit("messageSeen", messageId);
  }

 void startTyping(String conversationId,String userId) {
  print("Emitting start typing event");
  socket.emit("typing", {"conversationId": conversationId,"userId": userId});
}

void stopTyping(String conversationId, String userId) {
  print("Emitting stop typing event");
  socket.emit("stopTyping", {"conversationId": conversationId,"userId": userId});
}

void listenForTyping(Function(String, String) onTyping) {

    socket.off("typing"); // ✅ Remove old listener
    socket.on("typing", (data) {
      print("Received typing event: $data");
      onTyping(data['conversationId'], data['userId']);
    });
  
}


void listenForStopTyping(Function(String, String) onStopTyping) {
  print("Listening for stop typing event");
  socket.off("stopTyping");
  socket.on("stopTyping", (data) {
    String conversationId = data['conversationId']; // ✅ Extract conversationId
    String senderId = data['userId']; // ✅ Extract senderId (who stopped typing)
    
    onStopTyping(conversationId, senderId);
  });
}


  IO.Socket get socket => _socket;
}
