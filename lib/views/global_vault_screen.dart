import 'package:flutter/material.dart';
import '../models/academic_models.dart';
import '../services/firebase_service.dart';
import 'subject_vault_screen.dart';

class GlobalVaultScreen extends StatelessWidget {
  final FirebaseService _dbService = FirebaseService();
  final String currentSemesterId = 'sem_01';

  GlobalVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Study Vaults', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Subject>>(
        stream: _dbService.streamSubjects(currentSemesterId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No subjects found.", style: TextStyle(color: Colors.grey)));

          final subjects = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1, // Makes the cards slightly wider than tall
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SubjectVaultScreen(subject: subject)),
                  );
                },
                child: Card(
                  color: Colors.grey[850],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_copy, size: 48, color: Colors.indigoAccent),
                      const SizedBox(height: 12),
                      Text(subject.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text("${subject.creditPoints} Credits", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}