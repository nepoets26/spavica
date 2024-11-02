import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserMenu extends StatelessWidget {
  final AuthService authService;

  const UserMenu({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return AlertDialog(
      title: Text('Welcome ${user?.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user?.photoURL != null)
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(user!.photoURL!),
            ),
          const SizedBox(height: 351),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              Navigator.pop(context);
              await authService.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}