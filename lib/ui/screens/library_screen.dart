import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_library.dart';
import '../app_nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'list_screens.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibrary>();
    final sub = AppTheme.secondaryText(context);
    final recent = lib.recentlyAdded.take(24).toList();

    Widget row(IconData icon, String label, int count, Widget page) => Column(children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(icon, color: AppTheme.accent, size: 26),
            title: Text(label, style: const TextStyle(fontSize: 20)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$count', style: TextStyle(color: sub, fontSize: 15)),
              Icon(Icons.chevron_right_rounded, color: sub),
            ]),
            onTap: () => AppNav.push(page),
          ),
          const Divider(indent: 64),
        ]);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: lib.load,
          child: CustomScrollView(slivers: [
            const SliverToBoxAdapter(child: LargeTitle('Library')),
            SliverToBoxAdapter(
              child: Column(children: [
                row(Icons.mic_external_on_rounded, 'Artists', lib.artists.length, ArtistsScreen(artists: lib.artists)),
                row(Icons.album_rounded, 'Albums', lib.albums.length, AlbumsScreen(title: 'Albums', albums: lib.albums)),
                row(Icons.music_note_rounded, 'Songs', lib.songs.length, SongsScreen(title: 'Songs', songs: lib.songs)),
              ]),
            ),
            const SliverToBoxAdapter(child: SectionHeader('Recently Added')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => AlbumCard(recent[i]),
                  childCount: recent.length,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
