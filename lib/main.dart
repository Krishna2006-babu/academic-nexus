import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this at the top
// Import your screens here
import 'views/login_screen.dart';
import 'views/attendance_dashboard.dart';// Change this to your actual main screen file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the secret API key
  await dotenv.load(fileName: ".env"); 
  
  // Initialize Firebase ONCE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Run the app ONCE
  runApp(const AcademicNexusApp());
}

class AcademicNexusApp extends StatelessWidget {
  const AcademicNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Academic Nexus',
      theme: ThemeData(primarySwatch: Colors.indigo),
      // THE GATEKEEPER IS HERE
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If the app is still checking their login status, show a loader
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF212121), // grey[900]
              body: Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
            );
          }
          
          // If they have a valid session, let them in!
          if (snapshot.hasData) {
            return const AttendanceDashboard(); // <--- PUT YOUR MAIN SCREEN WIDGET HERE
          }

          // Otherwise, force them to log in
          return const LoginScreen();
        },
      ),
    );
  }
}