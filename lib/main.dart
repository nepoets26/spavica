import 'package:flutter/material.dart';
import 'package:youtube_player_iframe_example/pages/home_page.dart';
import 'package:youtube_player_iframe_example/pages/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import '../services/auth_service.dart';
import 'theme/app_theme.dart';
import 'services/user_service.dart';
import 'theme/blue_green_theme.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    name: "spavica-app",
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Bật persistence cho Firestore
  try {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
    //print('✅ Firestore persistence đã được bật');
  } catch (e) {
    //print('⚠️ Lỗi khi bật Firestore persistence: $e');
  }

  // Cấu hình Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Run the app
  runApp(const YoutubeApp());
}

class YoutubeApp extends StatelessWidget {
  const YoutubeApp({super.key});

  ThemeData _getTheme(String themeName) {
    switch (themeName) {
      case "LightPurplePink":
        return AppTheme.lightTheme;
      case "LightBlueGreen":
        return BlueGreenTheme.lightTheme;
      default:
        return ThemeData.from(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            key: const ValueKey('loading'),
            theme: _getTheme("Dark"),
            home: const Center(child: CircularProgressIndicator()),
          );
        }

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => authSnapshot.hasData 
                ? const HomePage() 
                : const LoginPage(),
            ),
          ],
        );

        if (authSnapshot.hasData) {
          return StreamBuilder<UserPreferences>(
            stream: UserService().getUserPreferences(),
            builder: (context, prefsSnapshot) {
              final themeName = prefsSnapshot.hasData 
                  ? prefsSnapshot.data!.theme 
                  : "Dark";
              
              return MaterialApp.router(
                key: ValueKey('authenticated_${themeName}'),
                title: 'Spavica',
                theme: _getTheme(themeName),
                debugShowCheckedModeBanner: false,
                routerConfig: router,
              );
            },
          );
        }

        return MaterialApp.router(
          key: const ValueKey('unauthenticated'),
          title: 'Spavica',
          theme: _getTheme("Dark"),
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        );
      },
    );
  }
}