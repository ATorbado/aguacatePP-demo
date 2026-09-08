import 'package:flutter/material.dart';

import 'pages/vehicles_page.dart';

void main() {
  runApp(const MaquinariaMApp());
}

class MaquinariaMApp extends StatelessWidget {
  const MaquinariaMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaquinariaM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3EEE4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7700),
          primary: const Color(0xFFFF7700),
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const VehiclesPage(),
    );
  }
}
