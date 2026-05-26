import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/academic_models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch subjects for dashboard
  Stream<List<Subject>> streamSubjects(String semesterId) {
    return _db
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map<Subject>((doc) => Subject.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // --- ATTENDANCE LEDGER LOGIC ---
  Future<void> logAttendance(String semesterId, String subjectId, bool present, String dateString) async {
    try {
      await _db
          .collection('semesters')
          .doc(semesterId)
          .collection('subjects')
          .doc(subjectId)
          .update({
            'history.$dateString': present, 
          });
      debugPrint("SUCCESS: Logged attendance for $dateString");
    } catch (e) {
      debugPrint("FIREBASE ERROR: $e");
    }
  }

  // Create a new subject
  Future<void> addSubject(String semesterId, Subject subject) async {
    await _db
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .add(subject.toMap());
  }

  // --- DELETE LOGIC ---
  Future<void> deleteSubject(String semesterId, String subjectId) async {
    try {
      await _db
          .collection('semesters')
          .doc(semesterId)
          .collection('subjects')
          .doc(subjectId)
          .delete();
      debugPrint("SUCCESS: Subject permanently deleted!");
    } catch (e) {
      debugPrint("FIREBASE ERROR (Delete): $e");
    }
  }

  // --- UPDATE LOGIC ---
  Future<void> updateSubjectData(String semesterId, String subjectId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('semesters')
          .doc(semesterId)
          .collection('subjects')
          .doc(subjectId)
          .update(data);
      debugPrint("SUCCESS: Subject data updated!");
    } catch (e) {
      debugPrint("FIREBASE ERROR (Update): $e");
    }
  }

  // --- RESOURCE VAULT LOGIC ---
  Future<void> addResource(String semesterId, String subjectId, ResourceItem resource) async {
    try {
      await _db
          .collection('semesters')
          .doc(semesterId)
          .collection('subjects')
          .doc(subjectId)
          .collection('resources') 
          .add(resource.toMap());
      debugPrint("SUCCESS: Resource added to vault!");
    } catch (e) {
      debugPrint("FIREBASE ERROR (Add Resource): $e");
    }
  }

  // Listens to the vault for any new links
  Stream<List<ResourceItem>> streamResources(String semesterId, String subjectId) {
    return _db
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .doc(subjectId)
        .collection('resources')
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map<ResourceItem>((doc) => ResourceItem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}