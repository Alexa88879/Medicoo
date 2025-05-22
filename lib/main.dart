//lib\main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Make sure this is imported
import 'package:google_fonts/google_fonts.dart'; // Import google_fonts
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; // Make sure this is imported
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CureLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008080), // Main teal color
          primary: const Color(0xFF008080),   // Primary color for components
          secondary: const Color(0xFF6EB6B4), // A lighter teal for accents
          // You can define other colors like error, surface, background etc.
        ),
        useMaterial3: true,
        // Set Poppins as the default font family using google_fonts
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ).copyWith(
          // Example of customizing specific text styles if needed
          bodyLarge: GoogleFonts.poppins(fontSize: 16.0),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0),
          displayLarge: GoogleFonts.poppins(fontSize: 32.0, fontWeight: FontWeight.bold),
          // Add other styles as needed
        ),
        appBarTheme: AppBarTheme(
          // Ensure AppBar text also uses Poppins by default if not overridden
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF00695C), // Example color for AppBar title
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(
            color: Color(0xFF00695C), // Example color for AppBar icons
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.poppins( // Ensure buttons use Poppins
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.poppins(), // Ensure text buttons use Poppins
          )
        ),
        // You can apply Poppins to other specific widget themes as well
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// Placeholder MyHomePage - can be removed if not used
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              // Example of explicitly using Poppins for a specific Text widget
              // style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.headlineMedium),
              style: Theme.of(context).textTheme.headlineMedium, // Will inherit Poppins
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
