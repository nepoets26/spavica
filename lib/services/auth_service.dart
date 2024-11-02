import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com' : null,
    scopes: [
      'email',
      'profile',
    ],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Thêm phương thức này để khởi tạo persistence
  Future<void> initializeAuth() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({
            'login_hint': '',
            'prompt': 'select_account'
          });
        return await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        if (!kIsWeb) _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }
}