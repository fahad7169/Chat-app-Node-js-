
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:chat_app/features/auth/presentation/widgets/auth_button.dart';
import 'package:chat_app/features/auth/presentation/widgets/auth_input_field.dart';
import 'package:chat_app/features/auth/presentation/widgets/login_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _isButtonDisabled = false;

  final _formKey = GlobalKey<FormState>();

  void _onLoginPressed() {
    setState(() {
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
    });

    if (_emailError == null && _passwordError == null) {
      // Rate limit: disable for 2 seconds
      setState(() => _isButtonDisabled = true);
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) setState(() => _isButtonDisabled = false);
      });

      BlocProvider.of<AuthBloc>(context).add(
        LoginEvent(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return "Email is required.";
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value)) return "Enter a valid email.";
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return "Password is required.";
    if (value.length < 6) return "Password must be at least 6 characters.";
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthInputField(
                  hint: "Email",
                  icon: Icons.person,
                  controller: _emailController,
                  errorText: _emailError,
                  onChanged: (val) {
                    setState(() => _emailError = _validateEmail(val));
                  },
                ),
                SizedBox(height: 20),

                AuthInputField(
                  hint: "Password",
                  icon: Icons.lock,
                  controller: _passwordController,
                  isPassword: true,
                  errorText: _passwordError,
                  onChanged: (val) {
                    setState(() => _passwordError = _validatePassword(val));
                  },
                ),
                SizedBox(height: 20),

                BlocConsumer<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return Center(child: CircularProgressIndicator());
                    }

                    return AuthButton(
                      text: _isButtonDisabled ? "Please wait..." : "Login",
                      onPressed: _isButtonDisabled ? () {} : _onLoginPressed,
                    );
                  },
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      Navigator.pushNamedAndRemoveUntil(context, '/conversationPage', (route) => false);
                    } else if (state is AuthFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error)));
                    }
                  },
                ),

                SizedBox(height: 10),
                LoginPrompt(
                  title: "Don't have an account?",
                  subTitle: "Register",
                  onTap: () => Navigator.pushNamed(context, '/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
