import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/academic_models.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart'; // Added Auth Service for logout
import 'weekly_schedule.dart'; 
import 'sgpa_planner.dart';
import 'global_vault_screen.dart';
import 'ai_advisor_screen.dart';
class AttendanceDashboard extends StatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  final FirebaseService _dbService = FirebaseService();
  final String currentSemesterId = 'sem_01';
  DateTime _selectedDate = DateTime.now();

  void _showAddSubjectSheet() {
    String newName = '';
    TimeOfDay selectedTime = TimeOfDay.now();
    List<int> selectedDays = [];
    double selectedTarget = 75.0; 
    int selectedCredits = 4; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add New Subject", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Subject Name', labelStyle: TextStyle(color: Colors.grey)), onChanged: (val) => newName = val),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Credit Points:", style: TextStyle(color: Colors.white)),
                      DropdownButton<int>(
                        value: selectedCredits,
                        dropdownColor: Colors.grey[850],
                        style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        underline: Container(height: 2, color: Colors.indigoAccent),
                        items: [1, 2, 3, 4, 5, 6].map((int value) => DropdownMenuItem<int>(value: value, child: Text("$value Credits"))).toList(),
                        onChanged: (int? newValue) { if (newValue != null) setModalState(() => selectedCredits = newValue); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Target Attendance:", style: TextStyle(color: Colors.white)),
                      Text("${selectedTarget.toInt()}%", style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Slider(
                    value: selectedTarget, min: 50, max: 100, divisions: 10,
                    activeColor: Colors.indigoAccent, inactiveColor: Colors.grey[700],
                    label: "${selectedTarget.toInt()}%",
                    onChanged: (val) => setModalState(() => selectedTarget = val),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Class Time: ${selectedTime.format(context)}", style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.access_time, color: Colors.indigoAccent),
                    onTap: () async {
                      TimeOfDay? time = await showTimePicker(context: context, initialTime: selectedTime);
                      if (time != null) setModalState(() => selectedTime = time);
                    },
                  ),
                  const Text("Select Days:", style: TextStyle(color: Colors.white)),
                  Wrap(
                    spacing: 8.0,
                    children: List.generate(7, (index) {
                      int dayNum = index + 1;
                      List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      return FilterChip(
                        label: Text(dayNames[index]),
                        selected: selectedDays.contains(dayNum),
                        selectedColor: Colors.indigoAccent,
                        onSelected: (bool selected) {
                          setModalState(() { selected ? selectedDays.add(dayNum) : selectedDays.remove(dayNum); });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () async {
                        // Trap 1: Did they forget a name?
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a subject name!"), backgroundColor: Colors.redAccent));
                          return;
                        }
                        // Trap 2: Did they forget to pick a day?
                        if (selectedDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one day for this class!"), backgroundColor: Colors.orange));
                          return;
                        }

                        // If everything is filled out, send it to the secure vault!
                        try {
                          Subject newSubject = Subject(id: '', name: newName, creditPoints: selectedCredits, daysOfWeek: selectedDays, classTime: selectedTime.format(context), requiredPercentage: selectedTarget);
                          await _dbService.addSubject(currentSemesterId, newSubject);
                          
                          if (mounted) {
                            Navigator.pop(context); // Close the sheet
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subject safely secured in vault!"), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          // Trap 3: Did Firebase block it?
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Database Error: $e"), backgroundColor: Colors.red));
                        }
                      },
                      child: const Text("Save Subject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int viewedDayNumber = _selectedDate.weekday;
    final List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final String viewedDayName = dayNames[viewedDayNumber - 1];
    final String formattedDate = "${_selectedDate.day} ${monthNames[_selectedDate.month - 1]}";
    bool isActuallyToday = _selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isActuallyToday ? "Today's Classes" : "Historical Schedule", style: const TextStyle(fontSize: 14, color: Colors.white70)),
              Row(
                children: [
                  Text("$viewedDayName, $formattedDate", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
        actions: [
         
          // 1. Study Hub Folder
          IconButton(
            icon: const Icon(Icons.folder_special, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalVaultScreen())),
          ),
          // 2. SGPA Planner
          IconButton(
            icon: const Icon(Icons.track_changes, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SgpaPlannerScreen())),
          ),
          // 3. Weekly Timetable
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WeeklyScheduleScreen())),
          ),
          // 4. Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => AuthService().signOut(),
          ),
          // AI Advisor Button
          IconButton(
            icon: const Icon(Icons.smart_toy, color: Colors.greenAccent),
            tooltip: "AI Advisor",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AiAdvisorScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<Subject>>(
        stream: _dbService.streamSubjects(currentSemesterId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Error loading data', style: TextStyle(color: Colors.red)));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No subjects yet. Add one!", style: TextStyle(color: Colors.grey)));

          final viewedSubjects = snapshot.data!.where((sub) => sub.daysOfWeek.contains(viewedDayNumber)).toList();
          if (viewedSubjects.isEmpty) return const Center(child: Text("No classes scheduled for this date!", style: TextStyle(color: Colors.greenAccent, fontSize: 16)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewedSubjects.length,
            itemBuilder: (context, index) {
              final subject = viewedSubjects[index];
              final double percent = subject.attendancePercentage(_selectedDate) / 100;
              final double targetDecimal = subject.requiredPercentage / 100;
              bool isAlreadyMarked = subject.isMarkedOn(DateTime.now().toIso8601String().split('T')[0]);

              return Card(
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 45.0, lineWidth: 8.0, percent: percent,
                        center: Text("${subject.attendancePercentage(_selectedDate).toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        progressColor: percent >= targetDecimal ? Colors.greenAccent : (percent == 0 ? Colors.grey : Colors.redAccent),
                        backgroundColor: Colors.grey[700]!,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text("🕒 ${subject.classTime}", style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text("Attended: ${subject.attendedClasses(_selectedDate)} / ${subject.totalClasses(_selectedDate)}", style: TextStyle(color: Colors.grey[400])),
                            const SizedBox(height: 12),
                            Text(
                              percent >= targetDecimal
                                  ? "Safe to miss: ${subject.classesCanMiss(_selectedDate)} classes (Target: ${subject.requiredPercentage.toInt()}%)"
                                  : "Danger: Need more classes! (Target: ${subject.requiredPercentage.toInt()}%)",
                              style: TextStyle(color: percent >= targetDecimal ? Colors.green[300] : Colors.red[300], fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (isActuallyToday)
                              isAlreadyMarked 
                                ? const Row(children: [Icon(Icons.verified, color: Colors.greenAccent, size: 20), SizedBox(width: 8), Text("Marked today", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))])
                                : Row(
                                    children: [
                                      ElevatedButton.icon(onPressed: () => _dbService.logAttendance(currentSemesterId, subject.id, true, DateTime.now().toIso8601String().split('T')[0]), icon: const Icon(Icons.check, size: 16, color: Colors.white), label: const Text('Present'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(onPressed: () => _dbService.logAttendance(currentSemesterId, subject.id, false, DateTime.now().toIso8601String().split('T')[0]), icon: const Icon(Icons.close, size: 16, color: Colors.white), label: const Text('Absent'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubjectSheet, 
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}