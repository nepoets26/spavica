import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  
  // Chỉ khởi tạo GoogleSignIn cho mobile
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> initializeAuth() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential? userCredential;
      
      if (kIsWeb) {
        // Sử dụng signInWithPopup cho web
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({
            'prompt': 'select_account'
          });
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Sử dụng GoogleSignIn cho mobile
        final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential != null) {
        await _userService.initializeUserPreferences();
        print('Đã khởi tạo user preferences');
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        if (!kIsWeb && _googleSignIn != null) _googleSignIn!.signOut(),
      ]);
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }
}