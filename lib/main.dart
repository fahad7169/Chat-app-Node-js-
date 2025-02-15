import 'package:chat_app/core/theme.dart';
import 'package:chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:chat_app/features/auth/presentation/pages/register_page.dart';
import 'package:chat_app/features/conversations/data/repositories/conversation_repository_impl.dart';
import 'package:chat_app/features/conversations/data/datasources/conversation_remote_data_source.dart';
import 'package:chat_app/features/conversations/domain/usecases/fetch_conversations_use_case.dart';
import 'package:chat_app/features/conversations/presentation/bloc/conversation_bloc.dart';
import 'package:chat_app/features/conversations/presentation/pages/conversation_page.dart';
import 'package:chat_app/screens/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  final authRepository = AuthRepositoryImpl(
    authRemoteDataSource: AuthRemoteDataSource(),
  );

   final conversationRepository = ConversationRepositoryImpl(
    conversationRemoteDataSource: ConversationRemoteDataSource(),
  );


  
  runApp(MyApp(authRespository: authRepository, conversationRepositoryImpl: conversationRepository));
}

class MyApp extends StatelessWidget {
  final AuthRepositoryImpl authRespository;
  final ConversationRepositoryImpl conversationRepositoryImpl;
  const MyApp({super.key, required this.authRespository, required this.conversationRepositoryImpl});

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
                fetchConversationsUseCase: FetchConversationsUseCase(repository: conversationRepositoryImpl),
              ),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: ConversationPage(),
        routes: {
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterPage(),
          '/chatPage': (context) => ChatPage(),
          '/conversationPage': (context) => ConversationPage(),
        },
      ),
    );
  }
}
