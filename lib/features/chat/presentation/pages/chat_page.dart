import 'dart:async';

import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:chat_app/features/conversations/data/datasources/conversation_remote_data_source.dart';
import 'package:chat_app/features/conversations/data/repositories/conversation_repository_impl.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String mate;
  final String userId;
  final String contactId;
  final List<Map<String, String>> onlineUsers;
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.mate,
    required this.onlineUsers,
    required this.userId,
    required this.contactId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();

  final SocketService _socketService = SocketService();
  bool isTyping = false;
  bool shouldJumpToBottom = false;
  Timer? _typingTimer; // Timer for detecting typing stop
  bool isOtherUserOnline = false;

  bool showTypingIndicator = false;
  final ScrollController _scrollController = ScrollController();


  String conversationId = '';

  late ConversationRepositoryImpl conversationRepositoryImpl;
  late CheckOrCreateConversationUseCase checkOrCreateConversationUseCase;

  @override
  void initState() {
    super.initState();
    // Ensure Hive is initialized and the box is open
    _initializeHiveBox();

    if (Hive.isBoxOpen('messages')) {
      BlocProvider.of<ChatBloc>(
        context,
      ).add(LoadMessagesEvent(widget.conversationId));
    }

    //  WidgetsBinding.instance.addObserver(this);
    conversationId = widget.conversationId;
    // ✅ Initialize repository and use case inside initState
    conversationRepositoryImpl = ConversationRepositoryImpl(
      conversationRemoteDataSource: ConversationRemoteDataSource(),
    );

    checkOrCreateConversationUseCase = CheckOrCreateConversationUseCase(
      conversationsRepository: conversationRepositoryImpl,
    );

    if (conversationId.isEmpty) {
      _initializeConversation();
    }

    print("Received conversationId from widget: $conversationId");

    bool online = isChatUserOnline(widget.mate);
    if (online) {
      if (mounted) {
        setState(() {
          isOtherUserOnline = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isOtherUserOnline = false;
        });
      }
    }

    _setupTypingListeners();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // ✅ Remove existing listeners before adding new ones to avoid duplicates
    _socketService.socket.off('userOnline');
    _socketService.socket.off('userOffline');
    _socketService.socket.off('typing');
    _socketService.socket.off('stopTyping');
    _socketService.socket.off('messageStatusUpdated');

    _socketService.listenForTyping((typingConversationId, senderId) {
      print("$senderId is typing in $typingConversationId");
      if (mounted) {
        if (typingConversationId == conversationId &&
            senderId != widget.userId) {
          setState(() => showTypingIndicator = true);
        }
      }
    });

    _socketService.listenForStopTyping((typingConversationId, senderId) {
      print("$senderId stopped typing in $typingConversationId");
      if (mounted) {
        if (typingConversationId == conversationId &&
            senderId != widget.userId) {
          setState(() => showTypingIndicator = false);
        }
      }
    });

    _socketService.listenForUpdateStatus((conversationId, messageId, status) {
      BlocProvider.of<ChatBloc>(
        context,
      ).add(MessageStatusUpdatedEvent(conversationId, messageId, status));
    });

    _socketService.listenForUserOnline((otherUserId, username) {
      print("User $otherUserId is online");
      if (mounted) {
        setState(() {
          if (username == widget.mate) {
            isOtherUserOnline = true;
          }
        });
      }
    });

    _socketService.listenForUserOffline((otherUserId, username) {
      print("User $otherUserId is offline");
      if (mounted) {
        setState(() {
          if (username == widget.mate) {
            isOtherUserOnline = false;
          }
        });
      }
    });
  }

  void _setupTypingListeners() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !isTyping) {
        isTyping = true;
        BlocProvider.of<ChatBloc>(
          context,
        ).add(TypingStartedEvent(conversationId));
        _typingTimer?.cancel();
        _typingTimer = Timer(Duration(seconds: 2), () {
          isTyping = false;
          BlocProvider.of<ChatBloc>(context).add(TypingStopped(conversationId));
        });
      } else if (_messageController.text.isEmpty && isTyping) {
        isTyping = false;
        BlocProvider.of<ChatBloc>(context).add(TypingStopped(conversationId));
        _typingTimer?.cancel();
      }
    });
  }

  bool isChatUserOnline(String chatUsername) {
    return widget.onlineUsers.any((user) => user["username"] == chatUsername);
  }

  //   @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (state == AppLifecycleState.resumed) {
  //    print("App is back in the foreground");
  //    BlocProvider.of<ChatBloc>(
  //     context,
  //   ).add(LoadMessagesEvent(widget.conversationId));
  //   }
  // }

  Future<void> _initializeConversation() async {
    try {
      final newConversationId = await checkOrCreateConversationUseCase.call(
        contactId: widget.contactId,
      );

      if (newConversationId.isNotEmpty) {
        setState(() {
          conversationId = newConversationId;
        });
      }
    } catch (e) {
      print("Error creating or fetching conversation: $e");
    }
  }



  String formatTime(String createdAt) {
    final utcTime = DateTime.parse(createdAt);
    final localTime = utcTime.toLocal();
    return DateFormat('h:mm a').format(localTime); // e.g., 8:00 PM
  }

  @override
  void dispose() {
    _messageController.dispose();
    _typingTimer?.cancel();
    _scrollController.dispose();
    //  WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      BlocProvider.of<ChatBloc>(
        context,
      ).add(SendMessageEvent(conversationId, content, widget.contactId));
    }
    _messageController.clear();
  }

  void _initializeHiveBox() async {
    if (!Hive.isBoxOpen('messages')) {
      await Hive.openBox<MessageEntity>('messages');
    }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mate,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isOtherUserOnline)
                  Text("Online", style: Theme.of(context).textTheme.bodySmall),
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
            child: BlocListener<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is ChatLoadedState) {
                 shouldJumpToBottom = true;
        }
                
              },
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  // Add ScrollController for list view

                  if (state is ChatLoadingState) {
                    return Center(child: CircularProgressIndicator());
                  } else if (state is ChatLoadedState) {

                     if (shouldJumpToBottom && _scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
              shouldJumpToBottom = false; // reset it
            }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(20),
                      itemCount:
                          state.messages.length + (showTypingIndicator ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Check if this is the last item and typing indicator should be shown

                        if (showTypingIndicator &&
                            index == state.messages.length) {
                          return TypingIndicator();
                          // ✅ Custom typing indicator widget
                        }

                        final message = state.messages[index];

                        final isSentMessage = message.senderId == widget.userId;

                       // Trigger seen event with debounce
             if (!isSentMessage && message.status != "seen") {
                Future.delayed(const Duration(milliseconds: 300), () {
                 if (mounted) { // Check if widget is still in tree
                    BlocProvider.of<ChatBloc>(context).add(
                     MessageSeenEvent(message.id, widget.conversationId),
                  );
              }
      });
    }

                        if (isSentMessage) {
                          return _buildSentMessage(
                            context,
                            message.content,
                            message.status.toString(),
                            message.createdAt,
                          );
                        } else {
                          return _buildReceivedMessage(
                            context,
                            message.content,
                          );
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: DefaultColors.receiverMessage,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildSentMessage(
    BuildContext context,
    String message,
    String status,
    String time,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 5, bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: DefaultColors.senderMessage,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatTime(time),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 8),

            _buildStatusIndicator(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    final iconSize = 16.0;
    final color = Colors.white54;

    switch (status) {
      case "pending":
        return Icon(Icons.access_time, size: iconSize, color: color);
      case "sent":
        return Icon(Icons.check, size: iconSize, color: color);
      case "delivered":
        return Icon(Icons.done_all, size: iconSize, color: color);
      case "seen":
        return Icon(Icons.done_all, size: iconSize, color: Colors.blue);
      default:
        return const SizedBox.shrink();
    }
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
