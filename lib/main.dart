import 'package:flutter/material.dart';
import 'package:music_app/screen/music_list_page.dart';

void main() {
  runApp(const ModernMusicApp());
}

class ModernMusicApp extends StatefulWidget {
  const ModernMusicApp({super.key});

  @override
  State<ModernMusicApp> createState() => _ModernMusicAppState();
}

class _ModernMusicAppState extends State<ModernMusicApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zamonaviy Musiqa Pleer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        cardColor: Colors.black26,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      home: MusicListPage(),
    );
  }
}
