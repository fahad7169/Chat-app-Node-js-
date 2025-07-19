import 'dart:async';

import 'package:chat_app/core/api/firebase_api.dart';
import 'package:chat_app/core/constants.dart';
import 'package:chat_app/core/remote_config_service.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() {
  runZonedGuarded(() async {
    // ✅ Set zone errors to be fatal
    BindingBase.debugZoneErrorsAreFatal = true;

    // ✅ Initialize Flutter bindings inside the zone
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase first
    await Firebase.initializeApp();

    // Then initialize Hive
    await Hive.initFlutter();

    // Register Hive adapters
    Hive.registerAdapter(ConversationModelAdapter());
    Hive.registerAdapter(ContactEntityAdapter());
    Hive.registerAdapter(MessageEntityAdapter());

    // Open Hive boxes
    await Hive.openBox<ConversationModel>('conversations');
    await Hive.openBox<MessageEntity>('messages');
    await Hive.openBox<ContactEntity>('contacts');

    // Initialize Firebase services after Firebase is initialized
    await RemoteConfigService().initialize();
    await FirebaseApi().initNotifications();

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

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };

    runApp(
      MyApp(
        authRespository: authRepository,
        conversationRepositoryImpl: conversationRepository,
        messageRepository: messageRepository,
        contactsRepositories: contactsRepositories,
        isUserLoggedIn: isUserLoggedIn,
      ),
    );
  }, (error, stackTrace) {});
}

Future<bool> isLoggedIn() async {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final String? token = await storage.read(key: "token");

  // Step 1: Local check
  if (token == null || token.isEmpty) {
    return false; // Definitely not logged in
  }

  try {
    // Step 2: Attempt backend verification (optional but useful)
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/auth/validate-token'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(
          const Duration(seconds: 5),
        ); // Timeout to avoid blocking too long

    if (response.statusCode == 200) {
      return true; // Token is valid
    } else if (response.statusCode == 401) {
      // Token is invalid or expired → logout locally
      // Clear all storage (now safe to do)
      await storage.delete(key: "token");
      await storage.delete(key: "userId");

      Box<ConversationModel> _conversationBox = Hive.box<ConversationModel>(
        'conversations',
      );

      Box<MessageEntity> _messageBox = Hive.box<MessageEntity>('messages');

      Box<ContactEntity> _contactBox = Hive.box<ContactEntity>('contacts');

      if (Hive.isBoxOpen('conversations')) {
        await _conversationBox.clear();
      }
      if (Hive.isBoxOpen('messages')) {
        await _messageBox.clear();
      }
      if (Hive.isBoxOpen('contacts')) {
        await _contactBox.clear();
      }
      return false;
    } else {
      // Other errors (like 500) — assume user is logged in for now
      return true;
    }
  } catch (e) {
    // Network issues or timeout → assume user is still logged in
    return true;
  }
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
                checkOrCreateConversationUseCase:
                    CheckOrCreateConversationUseCase(
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
