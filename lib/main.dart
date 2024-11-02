import 'package:flutter/material.dart';
import 'package:youtube_player_iframe_example/pages/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run the app
  runApp(const YoutubeApp());
}

class YoutubeApp extends StatelessWidget {
  const YoutubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Spavica',
      theme: ThemeData.from(colorScheme: colorScheme),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}