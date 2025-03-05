import 'package:chat_app/core/socket_service.dart';
import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:chat_app/features/auth/presentation/pages/register_page.dart';
import 'package:chat_app/features/chat/data/datasources/messages_remote_data_source.dart';
import 'package:chat_app/features/chat/data/repositories/message_repository_impl.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/usecases/fetch_messages_use_case.dart';
import 'package:chat_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:chat_app/features/contacts/data/datasources/contacts_remote_data_sources.dart';
import 'package:chat_app/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chat_app/features/contacts/domain/entities/contact_entity.dart';
import 'package:chat_app/features/contacts/domain/usecases/add_contact_usecase.dart';
import 'package:chat_app/features/contacts/domain/usecases/fetch_contacts_usecase.dart';
import 'package:chat_app/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:chat_app/features/conversations/data/models/conversation_model.dart';
import 'package:chat_app/features/conversations/data/repositories/conversation_repository_impl.dart';
import 'package:chat_app/features/conversations/data/datasources/conversation_remote_data_source.dart';
import 'package:chat_app/features/conversations/domain/usecases/check_or_create_conversation_use_case.dart';
import 'package:chat_app/features/conversations/domain/usecases/fetch_conversations_use_case.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_bloc.dart';
import 'package:chat_app/features/conversations/presentation/pages/conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter(); // Initialize Hive



  Hive.registerAdapter(
    ConversationModelAdapter(),
  ); // ✅ Register the correct adapter
  Hive.registerAdapter(ContactEntityAdapter());
  Hive.registerAdapter(MessageEntityAdapter());
  

  await Hive.openBox<ConversationModel>(
    'conversations',
  ); // ✅ Open with the correct type
  await Hive.openBox<ContactEntity>('contacts');
  await Hive.openBox<MessageEntity>('messages');

  final socketService = SocketService();
  await socketService.initSocket();

  final authRepository = AuthRepositoryImpl(
    authRemoteDataSource: AuthRemoteDataSource(),
  );

  final conversationRepository = ConversationRepositoryImpl(
    conversationRemoteDataSource: ConversationRemoteDataSource(),
  );

  final messageRepository = MessageRepositoryImpl(
    remoteDataSource: MessagesRemoteDataSource(),
  );

  final contactsRepositories = ContactsRepositoryImpl(
    remoteDataSources: ContactsRemoteDataSources(),
  );

  final isUserLoggedIn = await isLoggedIn();

  runApp(
    MyApp(
      authRespository: authRepository,
      conversationRepositoryImpl: conversationRepository,
      messageRepository: messageRepository,
      contactsRepositories: contactsRepositories,
      isUserLoggedIn: isUserLoggedIn,
    ),
  );
}

Future<bool> isLoggedIn() async {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? token = await _storage.read(key: "token");
  print("Token at first load: $token");
  return token != null && token != ''; // User is logged in if token exists
  // return false;
}

class MyApp extends StatelessWidget {
  final AuthRepositoryImpl authRespository;
  final ConversationRepositoryImpl conversationRepositoryImpl;
  final MessageRepositoryImpl messageRepository;
  final ContactsRepositoryImpl contactsRepositories;
  final bool isUserLoggedIn;

  const MyApp({
    super.key,
    required this.authRespository,
    required this.conversationRepositoryImpl,
    required this.messageRepository,
    required this.contactsRepositories,
    required this.isUserLoggedIn,
  });

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create:
              (_) => AuthBloc(
                registerUseCase: RegisterUsecase(repository: authRespository),
                loginUseCase: LoginUsecase(repository: authRespository),
              ),
        ),

        BlocProvider(
          create:
              (_) => ConversationBloc(
                fetchConversationsUseCase: FetchConversationsUseCase(
                  repository: conversationRepositoryImpl,
                ),
              ),
        ),
        BlocProvider(
          create:
              (_) => ChatBloc(
                fetchMessagesUseCase: FetchMessagesUseCase(
                  messageRepository: messageRepository,
           
                ),
                checkOrCreateConversationUseCase:  CheckOrCreateConversationUseCase(
                      conversationsRepository: conversationRepositoryImpl,
                    ),
              ),
        ),
        BlocProvider(
          create:
              (_) => ContactsBloc(
                fetchContactsUsecase: FetchContactsUsecase(
                  contactsRepositories: contactsRepositories,
                ),
                addContactUsecase: AddContactUsecase(
                  contactsRepositories: contactsRepositories,
                ),
                checkOrCreateConversationUseCase:
                    CheckOrCreateConversationUseCase(
                      conversationsRepository: conversationRepositoryImpl,
                    ),
              ),
          lazy: false,
        ),
      ],

      child: MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey, // Set the global key
        theme: AppTheme.darkTheme,
        home: isUserLoggedIn ? const ConversationPage() : const LoginPage(),
        routes: {
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterPage(),
          '/conversationPage': (context) => ConversationPage(),
        },
      ),
    );
  }
}
