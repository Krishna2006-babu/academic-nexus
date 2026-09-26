import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/academic_models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Wait, nobody is logged in!");
    return user.uid;
  }

  Stream<List<Subject>> streamSubjects(String semesterId) {
    return _db
        .collection('users')
        .doc(_userId) 
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map<Subject>((doc) => Subject.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> logAttendance(String semesterId, String subjectId, bool present, String dateString) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
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

  Future<void> addSubject(String semesterId, Subject subject) async {
    await _db
        .collection('users')
        .doc(_userId)
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .add(subject.toMap());
  }

  Future<void> deleteSubject(String semesterId, String subjectId) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
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

  Future<void> updateSubjectData(String semesterId, String subjectId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
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

  Future<void> addResource(String semesterId, String subjectId, ResourceItem resource) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
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

  Stream<List<ResourceItem>> streamResources(String semesterId, String subjectId) {
    return _db
        .collection('users')
        .doc(_userId)
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

  // --- TEMPORARY RESCUE SCRIPT ---
  Future<void> rescueOldSubjects(String semesterId) async {
    try {
      var oldData = await _db
          .collection('semesters')
          .doc(semesterId)
          .collection('subjects')
          .get();

      for (var doc in oldData.docs) {
        await _db
            .collection('users')
            .doc(_userId)
            .collection('semesters')
            .doc(semesterId)
            .collection('subjects')
            .doc(doc.id) 
            .set(doc.data());
      }
      debugPrint("SUCCESS: Old subjects rescued!");
    } catch (e) {
      debugPrint("RESCUE ERROR: $e");
    }
  }

  // Saves the entire text conversation to Firestore
  Future<void> saveChatHistory(List<Map<String, dynamic>> messages) async {
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .doc('ai_advisor')
          .set({
        'history': messages,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint("SUCCESS: Chat history saved!");
    } catch (e) {
      debugPrint("Error saving chat history: $e");
    }
  }

  // Loads the previous conversation when the app opens
  Future<List<Map<String, dynamic>>> loadChatHistory() async {
    try {
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .doc('ai_advisor')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> rawHistory = data['history'] ?? [];
        return rawHistory.map((msg) => Map<String, dynamic>.from(msg)).toList();
      }
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
    return [];
  }
}