import 'package:flutter/material.dart';
import '../models/academic_models.dart';
import '../services/firebase_service.dart';

class SgpaPlannerScreen extends StatefulWidget {
  const SgpaPlannerScreen({super.key});

  @override
  State<SgpaPlannerScreen> createState() => _SgpaPlannerScreenState();
}

class _SgpaPlannerScreenState extends State<SgpaPlannerScreen> {
  final FirebaseService _dbService = FirebaseService();
  final String currentSemesterId = 'sem_01';
  
  // Back to a smooth continuous slider
  double targetSgpa = 8.0;

  // --- THE NEW GREEDY ALGORITHM ---
  Map<String, int> calculateTargetGrades(List<Subject> subjects) {
    Map<String, int> grades = {};
    int totalCredits = subjects.fold(0, (sum, sub) => sum + sub.creditPoints);
    if (totalCredits == 0) return grades;

    // We must hit or exceed this exact integer point target
    int requiredTotalPoints = (targetSgpa * totalCredits).ceil();

    // 1. Start by assuming a perfect 10 in every subject
    for (var sub in subjects) {
      grades[sub.id] = 10;
    }

    int currentPoints = totalCredits * 10;

    // If even all 10s isn't enough, it's impossible. Return 10s.
    if (currentPoints < requiredTotalPoints) return grades;

    // 2. The "Greedy Downgrade" - Relentlessly drop Hard classes first
    List<String> dropPriority = ['Hard', 'Medium', 'Easy'];
    bool droppedSomething;

    do {
      droppedSomething = false;

      for (String diff in dropPriority) {
        List<Subject> diffSubjects = subjects.where((s) => s.difficulty == diff).toList();
        
        // Sort by current grade descending to drop them evenly (e.g. 9,9 instead of 10,8)
        diffSubjects.sort((a, b) => grades[b.id]!.compareTo(grades[a.id]!));

        for (var sub in diffSubjects) {
          // We set a floor of 4 (passing grade)
          if (grades[sub.id]! > 4) {
            // If we drop this class by 1 grade, will we still have enough total points?
            if ((currentPoints - sub.creditPoints) >= requiredTotalPoints) {
              grades[sub.id] = grades[sub.id]! - 1;
              currentPoints -= sub.creditPoints;
              droppedSomething = true;
              break; // Break inner loop to restart priority check (always attacks Hard first)
            }
          }
        }
        if (droppedSomething) break; // Break outer loop to restart the do-while
      }
    } while (droppedSomething);

    return grades;
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Proactive SGPA Planner', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // The Target Slider Section
          StreamBuilder<List<Subject>>(
            stream: _dbService.streamSubjects(currentSemesterId),
            builder: (context, snapshot) {
              
              double actualAchievedSgpa = 0.0;
              bool isImpossible = false;

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final subjects = snapshot.data!;
                final targetGrades = calculateTargetGrades(subjects);
                int totalCredits = subjects.fold(0, (sum, sub) => sum + sub.creditPoints);
                int currentAchievablePoints = subjects.fold(0, (sum, sub) => sum + (targetGrades[sub.id]! * sub.creditPoints));
                int requiredPoints = (targetSgpa * totalCredits).ceil();
                
                isImpossible = currentAchievablePoints < requiredPoints;
                if (totalCredits > 0) {
                  actualAchievedSgpa = currentAchievablePoints / totalCredits;
                }
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const Text("Target SGPA:", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text(targetSgpa.toStringAsFixed(2), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                    Slider(
                      value: targetSgpa,
                      min: 5.0,
                      max: 10.0,
                      divisions: 50,
                      activeColor: Colors.indigoAccent,
                      inactiveColor: Colors.grey[700],
                      onChanged: (val) => setState(() => targetSgpa = val),
                    ),
                    if (snapshot.hasData && snapshot.data!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          isImpossible 
                            ? "Warning: Target is mathematically impossible!" 
                            : "Easiest path yields: ${actualAchievedSgpa.toStringAsFixed(2)} SGPA",
                          style: TextStyle(
                            color: isImpossible ? Colors.redAccent : Colors.greenAccent, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
          ),
          
          // The Results List
          Expanded(
            child: StreamBuilder<List<Subject>>(
              stream: _dbService.streamSubjects(currentSemesterId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Add subjects first!", style: TextStyle(color: Colors.grey)));

                final subjects = snapshot.data!;
                final targetGrades = calculateTargetGrades(subjects);
                
                int currentAchievablePoints = subjects.fold(0, (sum, sub) => sum + (targetGrades[sub.id]! * sub.creditPoints));
                int requiredPoints = (targetSgpa * subjects.fold(0, (sum, sub) => sum + sub.creditPoints)).ceil();
                bool isImpossible = currentAchievablePoints < requiredPoints;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    final requiredGrade = targetGrades[subject.id]!;

                    return Card(
                      color: Colors.grey[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subject.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text("${subject.creditPoints} Credits", style: TextStyle(color: Colors.grey[400])),
                                  const SizedBox(height: 8),
                                  DropdownButton<String>(
                                    value: subject.difficulty,
                                    dropdownColor: Colors.grey[850],
                                    style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold),
                                    underline: Container(height: 2, color: Colors.indigoAccent),
                                    items: ['Easy', 'Medium', 'Hard'].map((String value) {
                                      return DropdownMenuItem<String>(value: value, child: Text(value));
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        _dbService.updateSubjectData(currentSemesterId, subject.id, {'difficulty': newValue});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                const Text("Target", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(
                                  requiredGrade.toString(),
                                  style: TextStyle(
                                    fontSize: 32, 
                                    fontWeight: FontWeight.bold,
                                    color: isImpossible ? Colors.redAccent : Colors.greenAccent,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}