import 'package:chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_event.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:toastification/toastification.dart';

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
      // Show success toast
      toastification.show(
        context: context,
        title: Text("Contact added successfully!"),
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
      );
    } else if (state is ContactAddedError) {
      // Show error toast
      toastification.show(
        context: context,
        title: Text(state.message),
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
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
        body: BlocBuilder<ContactsBloc, ContactsState>(
          builder: (context, state) {
            if (state is ContactsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ContactsLoaded) {
              final contacts = state.contacts;

              if (contacts.isEmpty) {
                print("Contacts are empty");
                return RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("No contacts found"),
                        ),
                      ),
                    ],
                  ),
                );
              }

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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ChatPage(
                                  conversationId: "",
                                  mate: contact.username,
                                  onlineUsers: [],
                                  userId: userId,
                                  contactId: contact.id,
                                ),
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
                child: ListView(
                  // ✅ Scrollable widget
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
              child: ListView(
                // ✅ Scrollable widget
                physics: AlwaysScrollableScrollPhysics(), // Ensures scrolling
                children: [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No contacts found"),
                    ),
                  ),
                ],
              ),
            );
          },
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
    builder: (context) {
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text(
              'Add Contact',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: isLoading
                ? const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: "Enter contact email",
                      hintStyle: Theme.of(context).textTheme.bodyMedium,
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isNotEmpty) {
                          setState(() => isLoading = true);

                          // Add contact event
                          final bloc = BlocProvider.of<ContactsBloc>(context);
                          bloc.add(AddContactEvent(email: email));

                          // Delay slightly to ensure state updates — optional
                          await Future.delayed(const Duration(milliseconds: 700));

                          Navigator.pop(context); // close dialog after adding
                        }
                      },
                      child: Text(
                        'Add',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
          );
        },
      );
    },
  );
}



}