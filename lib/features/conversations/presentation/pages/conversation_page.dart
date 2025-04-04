import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:chat_app/features/contacts/presentation/pages/contacts_page.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_bloc.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_event.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversations_state.dart';
import 'package:chat_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:chat_app/core/logout.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage>
    with WidgetsBindingObserver {
  Map<String, bool> typingStatus = {}; // Stores typing status per conversation

  final SocketService _socketService = SocketService();
  final _storage = FlutterSecureStorage();
  List<Map<String, String>> _onlineUsers = [];
  String userId = '';
  // Add this
  late final VoidCallback _removeOnlineUsersListener;

  @override
  void initState() {
    super.initState();
    BlocProvider.of<ConversationBloc>(context).add(FetchConversations());

    _storage.read(key: 'userId').then((value) {
      if (value != null) {
        setState(() {
          userId = value;
        });

        // Mark user online only after userId is retrieved
        _setUserOnline();
      }
    });

    WidgetsBinding.instance.addObserver(this);

    // Store cleanup function when setting up listener
    _removeOnlineUsersListener = _socketService.fetchOnlineUsers((onlineUsers) {
      print("Online users: $onlineUsers"); // Now this should print
      if (mounted) {
        // ✅ Safety check
        setState(() => _onlineUsers = onlineUsers);
      }
    });
    _setupTypingListeners();
  }

  @override
  void dispose() {
    _removeOnlineUsersListener(); // ✅ Remove listener
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(); // App is back in the foreground
      
       BlocProvider.of<ConversationBloc>(context).add(FetchConversations());
    } else if (state == AppLifecycleState.paused) {
      _setUserOffline(); // App is minimized or in the background
    }
  }
  void _setupTypingListeners() {
    _socketService.socket.off('userOnline');
    _socketService.socket.off('userOffline');

    _socketService.listenForUserOnline((otherUserId, username) {
      print("User $otherUserId is online");
      if (mounted) {
        _onlineUsers.add({"userId": otherUserId, "username": username});
      }
    });

    _socketService.listenForUserOffline((otherUserId, username) {
      print("User $otherUserId is offline");
      if (mounted) {
        _onlineUsers.removeWhere((user) => user["userId"] == otherUserId);
      }
    });

  }

  void _setUserOnline() {
    print("User is Online $userId");
    // Send "user online" event to backend or socket
    _socketService.socket.emit('userOnline', {"userId": userId});
  }

  void _setUserOffline() {
    print("User is Offline");
    // Send "user offline" event to backend or socket
    _socketService.socket.emit('userOffline', {"userId": userId});
  }

  Future<void> _onRefresh() async {
    // Your refresh logic here
    BlocProvider.of<ConversationBloc>(context).add(RefreshConversations());
  }

  String formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.trim().isEmpty) {
      return "No messages yet"; // ✅ Handle null and empty string
    }

    try {
      DateTime messageTime = DateTime.parse(timestamp).toLocal();
      DateTime now = DateTime.now();
      Duration difference = now.difference(messageTime);

      if (difference.inDays == 0) {
        return DateFormat('h:mm a').format(messageTime);
      } else if (difference.inDays == 1) {
        return "Yesterday";
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(messageTime);
      } else {
        return DateFormat('d MMM yyyy').format(messageTime);
      }
    } catch (e) {
      return ""; // ✅ Catch parsing errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        actions: [
          IconButton(
            onPressed: () {
              _showLogoutDialog(context);
            },
            icon: Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Text("Recent", style: Theme.of(context).textTheme.bodySmall),
          ),
          Container(
            height: 100,
            padding: EdgeInsets.all(5),
            child: BlocBuilder<ConversationBloc, ConversationsState>(
              builder: (context, state) {
                if (state is ConversationsLoading) {
                  return Center(child: CircularProgressIndicator());
                } else if (state is ConversationsLoaded) {
                  var filteredConversations =
                      state.conversations
                          .where(
                            (conversation) => conversation.lastMessage != '',
                          )
                          .toList(); // Exclude conversations with no messages

                  if (filteredConversations.length > 5) {
                    filteredConversations = filteredConversations.sublist(0, 5);
                  }

                  if (filteredConversations.isEmpty) {
                    return Center(child: Text("No recent conversations"));
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = filteredConversations[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ChatPage(
                                    conversationId: conversation.id,
                                    mate: conversation.participantName,
                                    onlineUsers: _onlineUsers,
                                    userId: userId,
                                    contactId: "",
                                  ),
                            ),
                          );
                        },
                        child: _buildRecentContact(
                          conversation.participantName,
                          context,
                        ),
                      );
                    },
                  );
                } else {
                  return Center(child: Text("No recent conversations"));
                }
              },
            ),
          ),

          SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DefaultColors.messageListPage,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: BlocBuilder<ConversationBloc, ConversationsState>(
                builder: (context, state) {
                  print("Current state: $state");
                  if (state is ConversationsLoading) {
                    return Center(child: CircularProgressIndicator());
                  } else if (state is ConversationsLoaded) {
                    final filteredConversations =
                        state.conversations
                            .where(
                              (conversation) => conversation.lastMessage != '',
                            )
                            .toList(); // Exclude conversations with no messages

                    if (filteredConversations.isEmpty) {
                      return Center(child: Text("No active conversations"));
                    }

                    return RefreshIndicator(
                      onRefresh: () => _onRefresh(),
                      child: ListView.builder(
                        itemCount: filteredConversations.length,
                        itemBuilder: (context, index) {
                          final conversation = filteredConversations[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ChatPage(
                                        conversationId: conversation.id,
                                        mate: conversation.participantName,
                                        onlineUsers: _onlineUsers,
                                        userId: userId,
                                        contactId: "",
                                      ),
                                ),
                              );
                            },
                            child: _buildMessageTile(
                              conversation.participantName,
                              conversation.lastMessage,
                              formatTimestamp(
                                conversation.lastMessageTime?.toString() ?? "",
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  } else if (state is ConversationsError) {
                    return RefreshIndicator(
    onRefresh: () => _onRefresh(),
    child: ListView( // ✅ Scrollable widget
      physics: AlwaysScrollableScrollPhysics(), // Ensures scrolling
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(state.message),
          ),
        ),
      ],
    ),
  );
                  }
                  return RefreshIndicator(
    onRefresh: () => _onRefresh(),
    child: ListView( // ✅ Scrollable widget
      physics: AlwaysScrollableScrollPhysics(), // Ensures scrolling
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text("No active conversations"),
          ),
        ),
      ],
    ),
  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle floating action button press
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ContactsPage()),
          );
        },
        backgroundColor: Color(0xFF7A8194),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRecentContact(String name, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(
              'https://www.nosm.ca/wp-content/uploads/2024/01/Photo-placeholder-1024x1024.jpg',
            ),
          ),
          SizedBox(height: 5),
          Text(name, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

 void _showLogoutDialog(BuildContext context) {
  bool isLoading = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            'Logout',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: SizedBox(
            height: 50, // Fixed height to prevent resizing
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : Text(
                    'Are you sure you want to logout?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
          actions: isLoading
              ? []
              : [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () async {
                      setState(() => isLoading = true);
                      final success = await logout();
                      setState(() => isLoading = false);

                      if (success) {
                        navigatorKey.currentState?.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => LoginPage()),
                          (route) => false,
                        );
                      } else {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Logout failed. Try again.")),
                        );
                      }
                    },
                    child: Text(
                      'Logout',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
        ),
      );
    },
  );
}



  Widget _buildMessageTile(String name, String message, String time) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(
          'https://www.nosm.ca/wp-content/uploads/2024/01/Photo-placeholder-1024x1024.jpg',
        ),
      ),
      title: Text(
        name,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        message,
        style: TextStyle(color: Colors.grey),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(time, style: TextStyle(color: Colors.grey)),
    );
  }
}
