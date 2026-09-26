import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Get the currently logged-in user
  User? get currentUser => _auth.currentUser;

  // 2. Listen to login/logout changes in real-time
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 3. Register a brand new user
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      return credential.user;
    } catch (e) {
      debugPrint("SIGN UP ERROR: $e");
      return null;
    }
  }

  // 4. Log in an existing user
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );
      return credential.user;
    } catch (e) {
      debugPrint("SIGN IN ERROR: $e");
      return null;
    }
  }

  // 5. Log out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}