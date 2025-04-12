import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/ladybug_logo_removebg.png',
              height: 123.0,
              width: 164.0,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Spavica',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final authService = AuthService();
                  await authService.signInWithGoogle();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Login failed: $e')),
                    );
                  }
                }
              },
              icon: Image.asset(
                'assets/google_logo.png',
                height: 24.0,
                width: 24.0,
              ),
              label: const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
