import 'dart:async';

import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String mate;
  const ChatPage({super.key, required this.conversationId, required this.mate});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final _storage = FlutterSecureStorage();
  String userId = '';
  final SocketService _socketService = SocketService();
  bool isTyping = false;

  Timer? _typingTimer; // Timer for detecting typing stop

  bool showTypingIndicator = false;
  final ScrollController _scrollController = ScrollController();

  

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    BlocProvider.of<ChatBloc>(
      context,
    ).add(LoadMessagesEvent(widget.conversationId));
    fetchUserId();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !isTyping) {
        isTyping = true;
        BlocProvider.of<ChatBloc>(
          context,
        ).add(TypingStartedEvent(widget.conversationId));

        // Cancel previous timer if exists
        _typingTimer?.cancel();

        // Start a new timer for detecting stop typing
        _typingTimer = Timer(Duration(seconds: 1), () {
          isTyping = false;
          BlocProvider.of<ChatBloc>(
            context,
          ).add(TypingStopped(widget.conversationId));
        });
      } else if (_messageController.text.isEmpty && isTyping) {
        isTyping = false;
        BlocProvider.of<ChatBloc>(
          context,
        ).add(TypingStopped(widget.conversationId));
        _typingTimer?.cancel(); // Stop the timer if text becomes empty
      }
    });

    _socketService.listenForTyping((typingConversationId, senderId) {
      print("$senderId is typing in $typingConversationId");
      if (typingConversationId == widget.conversationId && senderId != userId) {
        setState(() => showTypingIndicator = true);
      }
    });

    _socketService.listenForStopTyping((typingConversationId, senderId) {
      print("$senderId stopped typing in $typingConversationId");
      if (typingConversationId == widget.conversationId && senderId != userId) {
        setState(() => showTypingIndicator = false);
      }
    });
  }

  Future<void> fetchUserId() async {
    userId = await _storage.read(key: "userId") ?? '';
    setState(() {
      userId = userId;
    });
  }

  
   void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 2000), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      BlocProvider.of<ChatBloc>(
        context,
      ).add(SendMessageEvent(widget.conversationId, content));
    }
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                'https://www.nosm.ca/wp-content/uploads/2024/01/Photo-placeholder-1024x1024.jpg',
              ),
            ),
            SizedBox(width: 10),
            Column(
              children: [
                Text(
                  widget.mate,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (showTypingIndicator)
                  Text(
                    "Typing...",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                // Add ScrollController for list view
            
                if (state is ChatLoadingState) {
                  return Center(child: CircularProgressIndicator());
                } else if (state is ChatLoadedState) {
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: false,
                    padding: EdgeInsets.only(left: 20, right: 20),
                    itemCount:
                        state.messages.length + (showTypingIndicator ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Check if this is the last item and typing indicator should be shown
                      if (showTypingIndicator &&
                          index == state.messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: TypingIndicator(), // Your custom widget
                            ),
                          ),
                        );
                        // ✅ Custom typing indicator widget
                      }

                      final message = state.messages[index];
                      final isSentMessage = message.senderId == userId;
                      if (isSentMessage) {
                        return _buildSentMessage(context, message.content);
                      } else {
                        return _buildReceivedMessage(context, message.content);
                      }
                    },
                  );
                } else if (state is ChatErrorState) {
                  return Center(child: Text(state.message));
                }
                return Center(child: Text("No messages yet"));
              },
            ),
          ),
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildReceivedMessage(BuildContext context, String message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(right: 30, top: 5, bottom: 5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: DefaultColors.receiverMessage,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildSentMessage(BuildContext context, String message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(top: 5, bottom: 5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: DefaultColors.senderMessage,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DefaultColors.sentMessageInput,
        borderRadius: BorderRadius.circular(25),
      ),
      padding: EdgeInsets.symmetric(horizontal: 15),
      margin: EdgeInsets.all(15),
      child: Row(
        children: [
          GestureDetector(
            child: Icon(Icons.camera_alt, color: Colors.grey),
            onTap: () {},
          ),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Icon(Icons.send, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
