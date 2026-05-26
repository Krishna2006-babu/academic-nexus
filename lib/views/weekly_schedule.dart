import 'package:flutter/material.dart';
import '../models/academic_models.dart';
import '../services/firebase_service.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  final FirebaseService _dbService = FirebaseService();
  final String currentSemesterId = 'sem_01';

  // Warning Pop-up before deletion
  void _showDeleteDialog(BuildContext context, Subject subject) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Delete Class?", style: TextStyle(color: Colors.white)),
          content: Text(
            "Are you sure you want to permanently delete ${subject.name}? This will erase all attendance history for this class.",
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // Cancel
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                _dbService.deleteSubject(currentSemesterId, subject.id);
                Navigator.pop(dialogContext); // Close pop-up
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${subject.name} deleted"),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7, 
      initialIndex: DateTime.now().weekday - 1, 
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text(
            'Weekly Timetable',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.indigoAccent,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: days.map((day) => Tab(text: day)).toList(),
          ),
        ),
        body: StreamBuilder<List<Subject>>(
          stream: _dbService.streamSubjects(currentSemesterId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Error loading schedule', style: TextStyle(color: Colors.red))
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text("No classes scheduled yet.", style: TextStyle(color: Colors.grey))
              );
            }

            final allSubjects = snapshot.data!;

            return TabBarView(
              children: List.generate(7, (index) {
                int targetDayNumber = index + 1; 
                
                final daysClasses = allSubjects.where((sub) => sub.daysOfWeek.contains(targetDayNumber)).toList();

                if (daysClasses.isEmpty) {
                  return const Center(
                    child: Text(
                      "No classes today!", 
                      style: TextStyle(color: Colors.grey, fontSize: 16)
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: daysClasses.length,
                  itemBuilder: (context, idx) {
                    final subject = daysClasses[idx];
                    
                    // NEW: We now pass DateTime.now() into the percentage function!
                    final double currentPercent = subject.attendancePercentage(DateTime.now());

                    return Card(
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.book, color: Colors.indigoAccent),
                        ),
                        title: Text(
                          subject.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "🕒 ${subject.classTime}",
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Target: ${subject.requiredPercentage.toInt()}%", 
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12)
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  // NEW: Using the calculated currentPercent here
                                  "${currentPercent.toStringAsFixed(1)}%", 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    color: currentPercent >= subject.requiredPercentage ? Colors.green : Colors.redAccent
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8), 
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _showDeleteDialog(context, subject),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            );
          },
        ),
      ),
    );
  }
}