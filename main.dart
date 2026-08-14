import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.vish0420.audio.channel',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(const VideoPlayerApp());
}

class VideoPlayerApp extends StatefulWidget {
  const VideoPlayerApp({super.key});
  @override State<VideoPlayerApp> createState() => _VideoPlayerAppState();
}

class _VideoPlayerAppState extends State<VideoPlayerApp> {
  final ThemeService _themeService = ThemeService();
  @override void initState() { super.initState(); _themeService.load(); }
  @override Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeService>.value(value: _themeService, child: Consumer<ThemeService>(builder: (context, themeService, _) {
      final themeMode = switch (themeService.mode) { AppThemeMode.light => ThemeMode.light, AppThemeMode.dark => ThemeMode.dark, AppThemeMode.system => ThemeMode.system, AppThemeMode.gradient => ThemeMode.dark };
      return MaterialApp(title: 'Video Player', debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: themeMode, home: const HomeScreen());
    }));
  }
}
