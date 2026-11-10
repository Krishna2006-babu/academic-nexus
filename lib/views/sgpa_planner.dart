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

  int totalCredits =
      subjects.fold(0, (sum, sub) => sum + sub.creditPoints);

  if (subjects.isEmpty || totalCredits <= 0) return grades;

  int requiredPoints = (targetSgpa * totalCredits).ceil();
  int remainingBudget = totalCredits * 10 - requiredPoints;

  for (var sub in subjects) {
    grades[sub.id] = 10;
  }

  // Group subjects by difficulty.
  List<Subject> hard =
      subjects.where((s) => s.difficulty == 'Hard').toList();

  List<Subject> medium =
      subjects.where((s) => s.difficulty == 'Medium').toList();

  List<Subject> easy =
      subjects.where((s) => s.difficulty == 'Easy').toList();

  // Sort subjects by current reductions to maintain balance.
  void reduceGroup(List<Subject> group, int reduction) {
    group.sort((a, b) =>
        (10 - grades[a.id]!).compareTo(10 - grades[b.id]!));
    
    for (var sub in group) {
      if (grades[sub.id]! <= 4) continue;

      if (remainingBudget >= sub.creditPoints) {
        grades[sub.id] = grades[sub.id]! - 1;
        remainingBudget -= sub.creditPoints;
      }
    }
  }

  // Initial two reduction rounds for Hard.
  for (int round = 0; round < 2; round++) {
    reduceGroup(hard, round);
  }

  // Initial two reduction rounds for Medium.
  for (int round = 0; round < 2; round++) {
    reduceGroup(medium, round);
  }

  // Continue alternating Hard and Medium.
  while (remainingBudget > 0) {
    bool changed = false;

    // Hard gets priority.
    int beforeHard = remainingBudget;
    reduceGroup(hard, 0);

    if (remainingBudget < beforeHard) {
      changed = true;
    }

    // Then Medium.
    int beforeMedium = remainingBudget;
    reduceGroup(medium, 0);

    if (remainingBudget < beforeMedium) {
      changed = true;
    }

    if (!changed) break;
  }

  // Easy subjects are considered only after Hard and Medium.
  while (remainingBudget > 0) {
    int before = remainingBudget;
    reduceGroup(easy, 0);

    if (remainingBudget == before) break;
  }

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