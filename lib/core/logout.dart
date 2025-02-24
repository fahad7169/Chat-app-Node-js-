import 'package:chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:chat_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

Future<void> logout() async{
  // Clear stored tokens

final storage = FlutterSecureStorage();

  await storage.deleteAll();
  await Hive.deleteFromDisk();
  // Navigate to the login screen and remove all previous screens
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => LoginPage()),
    (route) => false, // This removes all previous routes
  );

  print("✅ User logged out and returned to Login Screen!");
}