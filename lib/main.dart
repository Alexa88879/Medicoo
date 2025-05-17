


import 'package:flutter/material.dart';
import 'login_page.dart'; // Make sure this file exists in your project

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthcare Login App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF219E9E),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

