import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

   IO.Socket? _socket; bool _isInitializing = false; // Guard against duplicate initializations

  final _storage = FlutterSecureStorage();

  SocketService._internal() {
    initSocket();
  }

  Future<void> initSocket() async {
    String token = await _storage.read(key: "token") ?? '';

   if (_socket != null || _isInitializing) return;
    _isInitializing = true;


    _socket = IO.io(
      'http://192.168.122.14:6000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.connect();
     String userId = await _storage.read(key: "userId") ?? '';

  
    _socket!.onConnect((_) {
      print("Socket connected: ${_socket!.id}");
      if(userId.isNotEmpty){
          socket.emit('joinConversation', {
            "userId": userId,
          });
      }

    });

    _socket!.onDisconnect((_) {
      print("Socket disconnected");
    });

    _socket!.onConnectError((data) => print("Socket connection error: $data"));
  }

  void markMessageDelivered(String messageId, String conversationId) {
    socket.emit("messageDelivered", {
      "messageId": messageId, // ✅ Corrected to use key-value pairs
      "conversationId": conversationId,
    });
    print("Emittted successfully");
  }

  void markMessageSeen(String messageId, String conversationId) {
    socket.emit("messageSeen", {
      "messageId": messageId, // ✅ Corrected to use key-value pairs
      "conversationId": conversationId,
    });
  }

  void startTyping(String conversationId, String userId) {
    print("Emitting start typing event");
    socket.emit("typing", {"conversationId": conversationId, "userId": userId});
  }

  void stopTyping(String conversationId, String userId) {
    print("Emitting stop typing event");
    socket.emit("stopTyping", {
      "conversationId": conversationId,
      "userId": userId,
    });
  }

  void listenForTyping(Function(String, String) onTyping) {
    socket.on("typing", (data) {
      print("Received typing event: $data");
      onTyping(data['conversationId'], data['userId']);
    });
  }

  void listenForStopTyping(Function(String, String) onStopTyping) {
    print("Listening for stop typing event");

    socket.on("stopTyping", (data) {
      String conversationId =
          data['conversationId']; // ✅ Extract conversationId
      String senderId =
          data['userId']; // ✅ Extract senderId (who stopped typing)

      onStopTyping(conversationId, senderId);
    });
  }

  void listenForUpdateStatus(Function(String, String, String) onUpdateStatus) {
    print("Listening for update status event");

    socket.on("messageStatusUpdated", (data) {
      print("Received update status event: $data");
      String conversationId =
          data['conversationId']; // ✅ Extract conversationId
      String messageId = data['messageId']; // ✅ Extract messageId
      String status = data['status']; // ✅ Extract status

      onUpdateStatus(conversationId, messageId, status);

      print("Received update status event: $data");
    });
  }

  void listenForUserOnline(Function(String,String) onUserOnline) {
    print("Listening for user online event");

    socket.on("userOnline", (data) {
      print("Received user online event: $data");
      String otherUserId = data['userId']; // ✅ Extract userId
       String username = data['username'];
      onUserOnline(otherUserId,username);
    });
  }

  void listenForUserOffline(Function(String, String) onUserOffline) {
    print("Listening for user offline event");
    socket.on("userOffline", (data) {
      print("Received user offline event: $data");
      String otherUserId = data['userId']; // ✅ Extract userId
      String username = data['username'];
      onUserOffline(otherUserId, username);
    });
  }


 // In SocketService
Function() fetchOnlineUsers(
  Function(List<Map<String, String>>) onOnlineUsersReceived,
) {
  socket.emit("getOnlineUsers");
  
  void listener(dynamic data) {
    print("Received online users: $data");

    if (data is! List) { // ✅ Validate data type
      print("Invalid online users data format");
      return;
    }

    try {
      List<Map<String, String>> onlineUsersFetched = [];
      for (final user in data.cast<Map<dynamic, dynamic>>()) {
        onlineUsersFetched.add({
          "userId": user["userId"]?.toString() ?? '', // ✅ Ensure String
          "username": user["username"]?.toString() ?? '',
        });
      }
      onOnlineUsersReceived(onlineUsersFetched);
    } catch (e) {
      print("Error parsing online users: $e");
    }
  }

  socket.on("onlineUsersList", listener);
  return () => socket.off("onlineUsersList", listener); // Return cleanup
}

  // Getter with null safety check
  IO.Socket get socket {
    if (_socket == null) {
      throw Exception(
          'Socket not initialized. Call initSocket() before accessing.');
    }
    return _socket!;
  }
}
