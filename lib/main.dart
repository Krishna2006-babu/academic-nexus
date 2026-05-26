import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'views/attendance_dashboard.dart';

void main() async {
  // Tells Flutter to wait until the engine is fully ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // Physically connects your app to the cloud
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AcademicNexusApp());
}

class AcademicNexusApp extends StatelessWidget {
  const AcademicNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academic Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // Bypasses any navigation bars and boots straight to the dashboard
      home: const AttendanceDashboard(), 
    );
  }
}