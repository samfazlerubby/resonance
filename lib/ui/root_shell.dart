import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/media_library.dart';
import 'app_nav.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/mini_player.dart';

/// Tabs (Home / Library / Search), each with its own page stack, plus the
/// mini player that floats above the tab bar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _roots = [HomeScreen(), LibraryScreen(), SearchScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<MediaLibrary>().load());
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibrary>();

    Widget body;
    switch (lib.status) {
      case LibraryStatus.idle:
      case LibraryStatus.loading:
        body = lib.songs.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : _tabs();
      case LibraryStatus.noPermission:
        body = EmptyState(
          icon: Icons.library_music_rounded,
          title: 'Allow access to your music',
          message: 'Resonance plays the songs stored on this phone. It needs permission to see them.',
          action: Column(children: [
            FilledButton(onPressed: lib.load, child: const Text('Try Again')),
            TextButton(onPressed: openAppSettings, child: const Text('Open Settings')),
          ]),
        );
      case LibraryStatus.error:
        body = EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Couldn’t read your music',
          message: lib.errorMessage ?? 'Unknown error',
          action: FilledButton(onPressed: lib.load, child: const Text('Try Again')),
        );
      case LibraryStatus.ready:
        body = lib.songs.isEmpty
            ? EmptyState(
                icon: Icons.music_off_rounded,
                title: 'No music found',
                message: 'Copy MP3, M4A, FLAC or other audio files to your phone (for example into the Music folder), then tap Rescan.',
                action: FilledButton(onPressed: lib.load, child: const Text('Rescan')),
              )
            : _tabs();
    }

    return ValueListenableBuilder<int>(
      valueListenable: AppNav.tab,
      builder: (context, tab, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (!AppNav.handleBack()) SystemNavigator.pop();
        },
        child: Scaffold(
          extendBody: true,
          body: body,
          bottomNavigationBar: lib.songs.isEmpty
              ? null
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const MiniPlayer(),
                  NavigationBar(
                    selectedIndex: tab,
                    onDestinationSelected: (i) {
                      if (i == tab) {
                        // Tapping the current tab again goes back to its start.
                        AppNav.tabKeys[i].currentState?.popUntil((r) => r.isFirst);
                      }
                      AppNav.tab.value = i;
                    },
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
                      NavigationDestination(icon: Icon(Icons.library_music_rounded), label: 'Library'),
                      NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
                    ],
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _tabs() => ValueListenableBuilder<int>(
        valueListenable: AppNav.tab,
        builder: (_, tab, __) => IndexedStack(
          index: tab,
          children: [
            for (var i = 0; i < _roots.length; i++)
              Navigator(
                key: AppNav.tabKeys[i],
                onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _roots[i]),
              ),
          ],
        ),
      );
}
