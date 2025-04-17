import 'dart:async';
import 'dart:convert';

import 'package:chat_app/core/constants.dart';
import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:chat_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:chat_app/features/conversations/data/datasources/conversation_remote_data_source.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:chat_app/features/conversations/data/repositories/conversation_repository_impl.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();

  final SocketService _socketService = SocketService();
  bool isTyping = false;

  Timer? _typingTimer; // Timer for detecting typing stop
  bool isOtherUserOnline = false;
  bool showTypingIndicator = false;
  final ScrollController _scrollController = ScrollController();
  bool _shouldAutoScroll = true;
  double _lastScrollPosition = 0;
  bool isDeleting = false;
  Set<String> selectedMessageIds = {};

  final _storage = FlutterSecureStorage();

  String conversationId = '';

  late ConversationRepositoryImpl conversationRepositoryImpl;
  late CheckOrCreateConversationUseCase checkOrCreateConversationUseCase;

  @override
  void initState() {
    super.initState();
    // Ensure Hive is initialized and the box is open
    _initializeHiveBox();
    _scrollController.addListener(_handleScroll);

    if (Hive.isBoxOpen('messages')) {
      BlocProvider.of<ChatBloc>(
        context,
      ).add(LoadMessagesEvent(widget.conversationId));
    }

    WidgetsBinding.instance.addObserver(this);
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
    _socketService.socket.off('receiveMessage');

    _socketService.listenForTyping((typingConversationId, senderId) {
      if (mounted) {
        if (typingConversationId == conversationId &&
            senderId != widget.userId) {
          if (mounted) {
            setState(() => showTypingIndicator = true);
          }
        }
      }
    });

    _socketService.listenForMessageReceived((data) {
      if (mounted) {
        BlocProvider.of<ChatBloc>(context).add(ReceiveMessageEvent(data));
      }
    });

    _socketService.listenForStopTyping((typingConversationId, senderId) {
      if (mounted) {
        if (typingConversationId == conversationId &&
            senderId != widget.userId) {
          if (mounted) {
            setState(() => showTypingIndicator = false);
          }
        }
      }
    });

    _socketService.listenForUpdateStatus((conversationId, messageId, status) {
      BlocProvider.of<ChatBloc>(
        context,
      ).add(MessageStatusUpdatedEvent(conversationId, messageId, status));
    });

    _socketService.listenForUserOnline((otherUserId, username) {
      if (mounted) {
        setState(() {
          if (username == widget.mate) {
            isOtherUserOnline = true;
          }
        });
      }
    });

    _socketService.listenForUserOffline((otherUserId, username) {
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
      if (_messageController.text.isNotEmpty && !isTyping && mounted) {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        BlocProvider.of<ChatBloc>(
          context,
        ).add(LoadMessagesEvent(widget.conversationId));
      }
    }
  }

  Future<void> _initializeConversation() async {
    try {
      final newConversationId = await checkOrCreateConversationUseCase.call(
        contactId: widget.contactId,
      );

      if (newConversationId.isNotEmpty) {
        if (mounted) {
          setState(() {
            conversationId = newConversationId;
          });
        }
      }
    } catch (e) {}
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
    _socketService.socket.off('userOnline');
    _socketService.socket.off('userOffline');
    _socketService.socket.off('typing');
    _socketService.socket.off('stopTyping');
    _socketService.socket.off('messageStatusUpdated');
    _socketService.socket.off('receiveMessage');
    _scrollController.removeListener(_handleScroll);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🔽 Deletion logic
  Future<void> deleteSelectedMessages() async {
    if (selectedMessageIds.isEmpty) {
      return; // No messages to delete
    }

    try {
      // Show a loading indicator or change state to indicate that deletion is in progress.
      setState(() {
        isDeleting =
            true; // Add this state variable to show a loading spinner if needed
      });
      // Convert Set to List before encoding to JSON
      final List<String> messageIdsList = selectedMessageIds.toList();
      String token = await _storage.read(key: "token") ?? '';
      // Call the API to delete messages
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/messages/deleteMessages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "messageIds": messageIdsList, // Send the message IDs to be deleted
        }),
      );

      // Check if the API request was successful (status code 200-299)
      if (response.statusCode == 200) {
        // Backup the message IDs before clearing
        final List<String> idsToDelete = List.from(selectedMessageIds);

        setState(() {
          if (mounted) {
            selectedMessageIds.clear(); // Now it's safe to clear
          }
        });

        Box<MessageEntity> _messagesBox = Hive.box<MessageEntity>('messages');

        for (var messageId in idsToDelete) {
          print("Deleting message with ID: $messageId");
          await _messagesBox.delete(messageId);
        }

        BlocProvider.of<ChatBloc>(
          context,
        ).add(RefreshMessagesFromHiveEvent(widget.conversationId));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Messages deleted successfully!')),
        );

        // After deleting messages, update the conversation box
        final remainingMessages =
            _messagesBox.values
                .where(
                  (message) => message.conversationId == widget.conversationId,
                )
                .toList();

        remainingMessages.sort(
          (a, b) => DateTime.parse(
            a.createdAt,
          ).compareTo(DateTime.parse(b.createdAt)),
        );


        if (remainingMessages.isNotEmpty) {
          // Update with the last message
          final lastMessage = remainingMessages.last;
          // Assuming you have a method to update the conversation box
          await _updateConversationBox(widget.conversationId, lastMessage);
        } else {
          // Update with empty data
          _updateConversationBox(widget.conversationId, null);
        }
      } else {
        // If not successful, handle the failure
        throw Exception('Failed to delete messages');
      }
    } catch (e) {
      // Handle any errors that occur during the API request
      setState(() {
        isDeleting = false; // Stop loading
      });

      // Optionally show an error message or retry logic
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete message(s)")));
    } finally {
      // Ensure loading state is reset even if the API request fails or succeeds
      setState(() {
        isDeleting = false;
      });
    }
  }

  // Add this method to update the conversation box
  Future<void> _updateConversationBox(
    String conversationId,
    MessageEntity? lastMessage,
  ) async {
    Box<ConversationModel> _conversationBox = Hive.box<ConversationModel>(
      'conversations',
    );

    final conversation = _conversationBox.get(conversationId);

    if (conversation != null) {
      if (lastMessage == null ||
          lastMessage.content == null ||
          lastMessage.createdAt == null ||
          lastMessage.status == null ||
          lastMessage.id == null) {
        // Update with empty data
        var newConversation = ConversationModel(
          id: conversationId,
          participantName: conversation.participantName,
          lastMessage: '',
          lastMessageTime: conversation.lastMessageTime,
          lastMessageStatus: '',
          lastMessageId: '',
        );

        await _conversationBox.put(conversationId, newConversation);
      } else {
        // Update with the last message
        var newConversation = ConversationModel(
          id: conversationId,
          participantName: conversation.participantName,
          lastMessage: lastMessage.content,
          lastMessageTime: DateTime.parse(
            lastMessage.createdAt,
          ),
          lastMessageStatus: lastMessage.status ?? '',
          lastMessageId: lastMessage.id,
        );

        await _conversationBox.put(conversationId, newConversation);
      }
    }
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

  void _handleScroll() {
    _lastScrollPosition = _scrollController.position.pixels;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedMessageIds.isNotEmpty) {
          setState(() {
            selectedMessageIds.clear();
          });
          return false; // Don't pop the screen, just clear selection
        }
        return true; // Let it pop
      },
      child: Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.white),
          title:
              selectedMessageIds.isEmpty
                  ? Row(
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
                            Text(
                              "Online",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  )
                  : Text(
                    "${selectedMessageIds.length} selected",
                    style: TextStyle(color: Colors.white),
                  ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: _buildAppBarActions(),
        ),

        body: Column(
          children: [
            Expanded(
              child: BlocListener<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state is ChatLoadedState &&
                      _scrollController.hasClients) {
                    if (_shouldAutoScroll) {
                      _scrollController.animateTo(
                        _scrollController.position.minScrollExtent,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                },
                child: BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, state) {
                    if (state is ChatLoadingState) {
                      return Center(child: CircularProgressIndicator());
                    } else if (state is ChatLoadedState) {
                      // Update scroll state only if it's necessary
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is UserScrollNotification) {
                            _shouldAutoScroll =
                                notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent * 0.9;
                          }
                          return false;
                        },
                        child: Stack(
                          children: [
                            // ListView with reversed messages
                            ListView.builder(
                              controller: _scrollController,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: false,
                              cacheExtent: 2000,
                              physics: const AlwaysScrollableScrollPhysics(),
                              reverse:
                                  true, // To load messages from bottom to top
                              padding: EdgeInsets.all(20),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) {
                                final reversedIndex =
                                    state.messages.length - 1 - index;

                                final message = state.messages[reversedIndex];
                                final isSentMessage =
                                    message.senderId == widget.userId;

                                // Trigger seen event with debounce
                                if (!isSentMessage &&
                                    message.status != "seen") {
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () {
                                      if (mounted) {
                                        BlocProvider.of<ChatBloc>(context).add(
                                          MessageSeenEvent(
                                            message.id,
                                            widget.conversationId,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }

                                if (isSentMessage) {
                                  return _buildSentMessage(
                                    context,
                                    message.id,
                                    message.content,
                                    message.status.toString(),
                                    message.createdAt,
                                  );
                                } else {
                                  return _buildReceivedMessage(
                                    context,
                                    message.content,
                                    message.createdAt,
                                  );
                                }
                              },
                            ),
                            // Typing indicator shown on top of the messages list
                            if (showTypingIndicator)
                              Positioned(
                                bottom: 0,
                                left: 20,
                                right: 20,
                                child: TypingIndicator(),
                              ),
                          ],
                        ),
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
      ),
    );
  }

  Widget _buildReceivedMessage(
    BuildContext context,
    String message,
    String time,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(right: 30, top: 5, bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: DefaultColors.receiverMessage,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSentMessage(
    BuildContext context,
    String messageId,
    String message,
    String status,
    String time,
  ) {
    bool isSelected = selectedMessageIds.contains(messageId);

    return GestureDetector(
      onLongPress: () async {
        // Vibrate when first selected
        HapticFeedback.vibrate();
        setState(() {
          selectedMessageIds.add(messageId);
        });
      },
      onTap: () {
        setState(() {
          if (selectedMessageIds.contains(messageId)) {
            selectedMessageIds.remove(messageId);
          } else if (selectedMessageIds.isNotEmpty) {
            selectedMessageIds.add(messageId);
          }
          // If empty selection and tap, do nothing (normal message tap)
        });
      },
      child: Container(
        color: isSelected ? Colors.grey[700] : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),

        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
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
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 8),
                _buildStatusIndicator(status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (isDeleting) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ];
    } else if (selectedMessageIds.isEmpty) {
      return [
        IconButton(
          onPressed: () {
            // Your normal search icon or other stuff
          },
          icon: const Icon(Icons.search, color: Colors.white),
        ),
      ];
    } else {
      return [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          offset: Offset(0, 40), // Positioning the menu below the 3 dots icon
          onSelected: (value) {
            if (value == 'delete') {
              deleteSelectedMessages();
            }
          },
          itemBuilder:
              (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5, // Add a slight shadow for a modern effect
          color: Colors.grey.withOpacity(
            0.2,
          ), // Dark background for modern look
        ),
      ];
    }
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
