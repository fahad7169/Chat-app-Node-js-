import 'package:chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_event.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {

    final _storage = FlutterSecureStorage();
      String userId = '';
  @override
  void initState() {
    super.initState();

    BlocProvider.of<ContactsBloc>(context).add(FetchContactsEvent());

    _storage.read(key: 'userId').then((value) {
      if (value != null) {
        setState(() {
          userId = value;
        });

      }
    });
  }

  Future<void> _onRefresh() async {
    BlocProvider.of<ContactsBloc>(context).add(RefreshContactsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactsBloc, ContactsState>(
      listener: (context, state) {
        if (state is ContactAdded) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: const Text(
                  "Success",
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text("Contact added successfully!"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );
        } else if (state is ContactAddedError) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: const Text(
                  "Error",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(state.message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Contacts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 70,
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.search, color: Colors.white),
            ),
          ],
        ),
        body: BlocListener<ContactsBloc, ContactsState>(
          listener: (context, state) {
            if (state is ConversationReady) {
              Navigator.pop(context); // Close loading dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChatPage(
                        conversationId: state.conversationId,
                        mate: state.contactName,
                        onlineUsers: [],
                        userId: userId,
                      ),
                ),
              );
            }
          },
          child: BlocBuilder<ContactsBloc, ContactsState>(
            builder: (context, state) {
              if (state is ContactsLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ContactsLoaded) {
                return RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: ListView.builder(
                    itemCount: state.contacts.length,
                    itemBuilder: (context, index) {
                      final contact = state.contacts[index];
                      print("Contact: $contact");
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            "https://www.nosm.ca/wp-content/uploads/2024/01/Photo-placeholder-1024x1024.jpg",
                          ),
                        ),
                        title: Text(
                          contact.username,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          contact.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible:
                                false, // Prevent closing the dialog
                            builder: (context) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          );

                          BlocProvider.of<ContactsBloc>(context).add(
                            CheckOrCreateConversationEvent(
                              contact.id,
                              contact.username,
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              } else if (state is ContactsError) {
                return RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: Center(child: Text(state.message)),
                );
              }
              return  RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: Center(child: Text('No contacts found'))
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddContactDialog(context);
          },
          backgroundColor: Color(0xFF7A8194),
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text(
              'Add Contact',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: "Enter contact email",
                hintStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            actions: [
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  final email = emailController.text.trim();
                  if (email.isNotEmpty) {
                    BlocProvider.of<ContactsBloc>(
                      context,
                    ).add(AddContactEvent(email: email));
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  'Add',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
    );
  }
}
