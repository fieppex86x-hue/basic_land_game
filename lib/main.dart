import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const BasicLandApp());
}

class BasicLandApp extends StatelessWidget {
  const BasicLandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Basic Land Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}