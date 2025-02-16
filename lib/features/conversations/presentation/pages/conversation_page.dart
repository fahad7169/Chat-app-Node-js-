import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_bloc.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_event.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversations_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {


  @override
  void initState() {
    super.initState();
    BlocProvider.of<ConversationBloc>(context).add(FetchConversations());
  }


String formatTimestamp(String timestamp) {
  DateTime messageTime = DateTime.parse(timestamp).toLocal();
  DateTime now = DateTime.now();
  Duration difference = now.difference(messageTime);

  if (difference.inDays == 0) {
    // Message is from today, show time (e.g., "10:30 AM")
    return DateFormat('h:mm a').format(messageTime);
  } else if (difference.inDays == 1) {
    // Message is from yesterday
    return "Yesterday";
  } else if (difference.inDays < 7) {
    // Message is from this week, show day name (e.g., "Monday")
    return DateFormat('EEEE').format(messageTime);
  } else {
    // Message is older than a week, show full date (e.g., "15 Feb 2025")
    return DateFormat('d MMM yyyy').format(messageTime);
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
            onPressed: () {},
            icon: Icon(Icons.search, color: Colors.white),
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
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildRecentContact("Fahad", context),
                _buildRecentContact("Ali", context),
                _buildRecentContact("Michael", context),
                _buildRecentContact("Johnson", context),
              ],
            ),
          ),

          SizedBox(height: 10,),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DefaultColors.messageListPage,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                )
              ),
              child:BlocBuilder<ConversationBloc, ConversationsState>(
                builder: (context, state) {
                  if(state is ConversationsLoading){
                    return Center(child: CircularProgressIndicator(),);
                  }
                  else if (state is ConversationsLoaded){
                  return ListView.builder(
                    itemCount: state.conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = state.conversations[index];

                      return  GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(
                          conversationId: conversation.id, 
                          mate: conversation.participantName,
                          )));
                        },
                        child: _buildMessageTile(
                           conversation.participantName, 
                         conversation.lastMessage,
                         formatTimestamp(conversation.lastMessageTime.toString()),
                           ),
                      );
                    },
             
                      );
                  }
                 else if (state is ConversationsError){
                  return Center(child: Text(state.message),);
                 }
                 return Center(child: Text("No conversations"),);
                }
              ),
            
              ),
            ),
        ],
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
            backgroundImage: NetworkImage('https://www.nosm.ca/wp-content/uploads/2024/01/Photo-placeholder-1024x1024.jpg'),
          ),
          SizedBox(height: 5),
          Text(name, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildMessageTile(String name, String message, String time) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage('https://www.nosm.ca/wp-content/uploads/2024/01/Photo-placeholder-1024x1024.jpg'),
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
