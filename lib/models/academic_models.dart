class Subject {
  String id;
  String name;
  int creditPoints;
  String? notesUrl;
  List<int> daysOfWeek; 
  String classTime;     
  double requiredPercentage; 
  String difficulty; 
  String takeawayNote; 
  // NEW: The Event Ledger! Stores exactly what happened on every single date.
  Map<String, bool> history; 

  Subject({
    required this.id,
    required this.name,
    required this.creditPoints,
    this.notesUrl,
    this.daysOfWeek = const [],
    this.classTime = '',
    this.requiredPercentage = 75.0,
    this.difficulty = 'Medium', 
    this.takeawayNote = '', 
    this.history = const {}, // Defaults to an empty ledger
  });

  // --- THE TIME MACHINE MATH ENGINE ---
  
  // Helper to grab only the history that happened BEFORE or ON the viewed date
  List<MapEntry<String, bool>> _getHistoryUpTo(DateTime limit) {
    String limitStr = limit.toIso8601String().split('T')[0];
    // Compares date strings alphabetically (e.g., '2026-05-15' <= '2026-05-21')
    return history.entries.where((e) => e.key.compareTo(limitStr) <= 0).toList();
  }

  // Dynamically counts total classes up to the viewed date
  int totalClasses(DateTime limitDate) => _getHistoryUpTo(limitDate).length;

  // Dynamically counts attended classes up to the viewed date
  int attendedClasses(DateTime limitDate) => _getHistoryUpTo(limitDate).where((e) => e.value).length;

  // Dynamically calculates percentage up to the viewed date
  double attendancePercentage(DateTime limitDate) {
    int total = totalClasses(limitDate);
    if (total == 0) return 0.0;
    return (attendedClasses(limitDate) / total) * 100;
  }

  int classesCanMiss(DateTime limitDate) {
    int total = totalClasses(limitDate);
    if (total == 0) return 0;
    int prospectiveTotal = total;
    int workingAttended = attendedClasses(limitDate);
    int missCount = 0;
    double targetDecimal = requiredPercentage / 100;
    
    while ((workingAttended / (prospectiveTotal + 1)) >= targetDecimal) {
      prospectiveTotal++;
      missCount++;
    }
    return missCount;
  }

  // Checks if the button should be locked for a specific date
  bool isMarkedOn(String dateString) {
    return history.containsKey(dateString);
  }

  // --- FIREBASE DATA CONVERSION ---
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'creditPoints': creditPoints,
      'notesUrl': notesUrl,
      'daysOfWeek': daysOfWeek,
      'classTime': classTime,
      'requiredPercentage': requiredPercentage, 
      'difficulty': difficulty, 
      'takeawayNote': takeawayNote,
      'history': history, // Saves the entire ledger to the cloud
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map, String documentId) {
    // Safely converts Firebase map into a strict Dart Map<String, bool>
    Map<String, bool> parsedHistory = {};
    if (map['history'] != null) {
      map['history'].forEach((key, value) {
        parsedHistory[key.toString()] = value as bool;
      });
    }

    return Subject(
      id: documentId,
      name: map['name'] ?? '',
      creditPoints: map['creditPoints']?.toInt() ?? 0,
      notesUrl: map['notesUrl'],
      daysOfWeek: List<int>.from(map['daysOfWeek'] ?? []), 
      classTime: map['classTime'] ?? '',                   
      requiredPercentage: map['requiredPercentage']?.toDouble() ?? 75.0, 
      difficulty: map['difficulty'] ?? 'Medium', 
      takeawayNote: map['takeawayNote'] ?? '',
      history: parsedHistory, 
    );
  }
}
// --- NEW: THE RESOURCE VAULT MODEL ---
class ResourceItem {
  String id;
  String title;
  String url;
  String type; // e.g., 'PDF', 'Video', 'Link', 'PYQ'
  String dateAdded;

  ResourceItem({
    required this.id,
    required this.title,
    required this.url,
    required this.type,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'type': type,
      'dateAdded': dateAdded,
    };
  }

  factory ResourceItem.fromMap(Map<String, dynamic> map, String documentId) {
    return ResourceItem(
      id: documentId,
      title: map['title'] ?? 'Untitled',
      url: map['url'] ?? '',
      type: map['type'] ?? 'Link',
      dateAdded: map['dateAdded'] ?? '',
    );
  }
}