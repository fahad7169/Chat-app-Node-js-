import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontSizes {
  static const small = 12.0;
  static const standard = 14.0;
  static const standardUp = 16.0;
  static const medium = 20.0;
  static const large = 28.0;
}

class DefaultColors {
  static const Color greyText = Color(0xFFB389C9);
  static const whiteText = Color(0xFFFFFFFF);
 static const senderMessage = Color(0xFF005C4B); // Pastel green
  static const receiverMessage = Color(0xFF373E4E);
  static const sentMessageInput = Color(0xFF3D4354);
  static const messageListPage = Color(0XFF292F3F);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData( 
      progressIndicatorTheme: ProgressIndicatorThemeData(color: Colors.white),
      primaryColor: Colors.white,
      scaffoldBackgroundColor: Color(0XFF1B202D),
      textTheme: TextTheme(
        titleMedium: GoogleFonts.roboto(
          fontSize: FontSizes.medium,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: FontSizes.large,
          color: Colors.white,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: FontSizes.small,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: FontSizes.standard,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: FontSizes.standardUp,
          color: Colors.white,
        ),
      )
    );
  }
}
