import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'services/media_library.dart';
import 'services/online_info.dart';
import 'services/player_controller.dart';
import 'ui/app_nav.dart';
import 'ui/root_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background playback + lock screen / notification controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.resonance.resonance.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
  );

  final online = OnlineInfo();
  await online.init();
  final library = MediaLibrary();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: online),
        ChangeNotifierProvider(create: (_) => PlayerController(library)),
      ],
      child: const ResonanceApp(),
    ),
  );
}

class ResonanceApp extends StatelessWidget {
  const ResonanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Resonance',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNav.rootKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const RootShell(),
      );
}
