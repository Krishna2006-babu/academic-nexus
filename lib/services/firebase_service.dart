import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Wait, nobody is logged in!");
    }
    return user.uid;
  }

  // ==========================================
  // STORAGE (PDF & IMAGE UPLOADS)
  // ==========================================

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  
Future<String> uploadVaultFile({
  required String semesterId,
  required String subjectId,
  required Uint8List bytes,
  required String originalFileName,
}) async {
  try {
    if (bytes.isEmpty) {
      throw Exception('Selected file is empty.');
    }

    debugPrint('UPLOAD STARTED: $originalFileName');
    debugPrint('FILE SIZE: ${bytes.length} bytes');

    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    final String cleanFileName = originalFileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );

    final String storagePath =
        'users/$_userId/semesters/$semesterId/subjects/$subjectId/vault/${timestamp}_$cleanFileName';

    final Reference ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: _getContentType(originalFileName),
    );

    final UploadTask uploadTask = ref.putData(bytes, metadata);

    final progressSubscription = uploadTask.snapshotEvents.listen(
      (snapshot) {
        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;

        if (total > 0) {
          final percentage = transferred / total * 100;

          debugPrint(
            'UPLOAD PROGRESS: ${percentage.toStringAsFixed(1)}%',
          );
        }
      },
      onError: (error) {
        debugPrint('UPLOAD STREAM ERROR: $error');
      },
    );

    try {
      final TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 90),
        onTimeout: () async {
          await uploadTask.cancel();

          throw TimeoutException(
            'Firebase upload timed out after 90 seconds.',
          );
        },
      );

      debugPrint('UPLOAD COMPLETED SUCCESSFULLY');

      final String downloadUrl = await snapshot.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 30));

      debugPrint('DOWNLOAD URL GENERATED');

      return downloadUrl;
    } finally {
      await progressSubscription.cancel();
    }
  } catch (e) {
    debugPrint('FIREBASE STORAGE ERROR: $e');
    rethrow;
  }
}


  Future<void> deleteStorageFileByUrl(String url) async {
    try {
      if (url.contains('firebasestorage.googleapis.com')) {
        final Reference ref = _storage.refFromURL(url);
        await ref.delete();

        debugPrint("SUCCESS: Associated storage file deleted!");
      }
    } catch (e) {
      debugPrint("STORAGE DELETE ERROR: $e");
    }
  }

  // ==========================================
  // SUBJECTS
  // ==========================================

  Stream<List<Subject>> streamSubjects(String semesterId) {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map<Subject>(
                (doc) => Subject.fromMap(doc.data(), doc.id),
              )
              .toList(),
        );
  }

  Future<void> logAttendance(
    String semesterId,
    String subjectId,
    bool present,
    String dateString,
  ) async {
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

  Future<void> deleteSubject(
    String semesterId,
    String subjectId,
  ) async {
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

  Future<void> updateSubjectData(
    String semesterId,
    String subjectId,
    Map<String, dynamic> data,
  ) async {
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

  // ==========================================
  // VAULT RESOURCES
  // ==========================================

  Future<void> addResource(
    String semesterId,
    String subjectId,
    ResourceItem resource,
  ) async {
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
      rethrow;
    }
  }

  Future<void> deleteResource(
    String semesterId,
    String subjectId,
    String resourceId,
    String resourceUrl,
  ) async {
    try {
      await deleteStorageFileByUrl(resourceUrl);

      await _db
          .collection('users')
          .doc(_userId)
          .collection('semesters')
          .doc(semesterId)
          .collection('subjects')
          .doc(subjectId)
          .collection('resources')
          .doc(resourceId)
          .delete();

      debugPrint("SUCCESS: Resource and file deleted!");
    } catch (e) {
      debugPrint("FIREBASE ERROR (Delete Resource): $e");
    }
  }

  Stream<List<ResourceItem>> streamResources(
    String semesterId,
    String subjectId,
  ) {
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
        .map(
          (snapshot) => snapshot.docs
              .map<ResourceItem>(
                (doc) => ResourceItem.fromMap(doc.data(), doc.id),
              )
              .toList(),
        );
  }

  // ==========================================
  // CHAT & RESCUE
  // ==========================================

  Future<void> rescueOldSubjects(String semesterId) async {
    try {
      final oldData = await _db
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

  // Save AI chat history
  Future<void> saveChatHistory(
    List<Map<String, dynamic>> messages,
  ) async {
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

  // Load AI chat history
  Future<List<Map<String, dynamic>>> loadChatHistory() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _db
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .doc('ai_advisor')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List<dynamic> rawHistory =
            data['history'] as List<dynamic>? ?? [];

        return rawHistory
            .map<Map<String, dynamic>>(
              (msg) => Map<String, dynamic>.from(msg as Map),
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }

    return [];
  }
}
