import 'package:flutter/material.dart';

class AppTheme {
  static const Color statusRed = Colors.red;
  static const Color statusOrange = Colors.orange;
  static const Color statusGreen = Colors.green;
  static Color statusGreenLight = Colors.green.shade200;
  static Color statusRedLight = Colors.red.shade200;
  static const Color onStatusColor = Colors.black;

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
    textTheme: const TextTheme(
      titleMedium: TextStyle(fontSize: 18), // For buttons
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // For section titles
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
    textTheme: const TextTheme(
      titleMedium: TextStyle(fontSize: 18), // For buttons
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // For section titles
    ),
  );
}
