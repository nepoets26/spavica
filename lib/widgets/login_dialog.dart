import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginDialog extends StatelessWidget {
  final AuthService authService;

  const LoginDialog({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Don't pop the dialog immediately
                  final result = await authService.signInWithGoogle();
                  if (result != null && context.mounted) {
                    Navigator.of(context).pop(); // Only pop after successful sign in
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Successfully signed in!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign in failed: ${e.toString()}')),
                    );
                  }
                }
              },
              icon: Image.asset(
                'assets/google_logo.png',
                height: 124,
              ),
              label: const Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}