import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:chat_app/features/auth/presentation/widgets/auth_button.dart';
import 'package:chat_app/features/auth/presentation/widgets/auth_input_field.dart';
import 'package:chat_app/features/auth/presentation/widgets/login_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _usernameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    BlocProvider.of<AuthBloc>(context).add(
      RegisterEvent(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }


  void _validateAndRegister() {
    setState(() {
      _usernameError = _usernameController.text.trim().isEmpty ? 'Username is required' : null;
      _emailError = !_emailController.text.contains('@') ? 'Enter a valid email' : null;
      _passwordError = _passwordController.text.length < 6 ? 'Password must be at least 6 characters' : null;
    });

    if (_usernameError == null && _emailError == null && _passwordError == null) {
      _onRegisterPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthInputField(
                  hint: "Username",
                  icon: Icons.person,
                  controller: _usernameController,
                  errorText: _usernameError,
                  onChanged: (_) => setState(() => _usernameError = null),
                ),
                SizedBox(height: 20),
                AuthInputField(
                  hint: "Email",
                  icon: Icons.email,
                  controller: _emailController,
                  errorText: _emailError,
                  onChanged: (_) => setState(() => _emailError = null),
                ),
                SizedBox(height: 20),
                AuthInputField(
                  hint: "Password",
                  icon: Icons.lock,
                  controller: _passwordController,
                  isPassword: true,
                  errorText: _passwordError,
                  onChanged: (_) => setState(() => _passwordError = null),
                ),
                SizedBox(height: 20),
                BlocConsumer<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return Center(child: CircularProgressIndicator());
                    }

                    return AuthButton(
                      text: "Register",
                      onPressed: _validateAndRegister,
                    );
                  },
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      Navigator.pushNamed(context, '/login');
                    } else if (state is AuthFailure) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(state.error)));
                    }
                  },
                ),
                SizedBox(height: 20),
                LoginPrompt(
                  title: "Already have an account?",
                  subTitle: "Login",
                  onTap: () {
                    Navigator.pushNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
