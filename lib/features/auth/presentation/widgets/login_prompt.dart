import 'package:flutter/material.dart';

class LoginPrompt extends StatelessWidget {

  final String title;
  final String subTitle;
  final VoidCallback onTap;


  const LoginPrompt({super.key, required this.title, required this.subTitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText
        (text: TextSpan(
          text: title,
          style: TextStyle(
            color: Colors.grey,
            
          ),
          children: [
            TextSpan(
              text: subTitle,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold
              )
            )
          ]
        ),
        
        ),
      ),
    );
  }
}