import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/media_library.dart';
import '../../services/player_controller.dart';
import '../app_nav.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import 'artist_screen.dart';
import 'list_screens.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // A random pick of albums that stays put until you pull to refresh.
  List<Album> _rediscover = [];
  int _seed = DateTime.now().millisecondsSinceEpoch;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibrary>();
    final player = context.read<PlayerController>();
    final recent = lib.recentlyAdded.take(12).toList();
    final topArtists = lib.topArtists.take(10).toList();
    if (_rediscover.isEmpty || _rediscover.any((a) => lib.albumById(a.id) == null)) {
      _rediscover = (List.of(lib.albums)..shuffle(Random(_seed))).take(8).toList();
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: () async {
            await lib.load();
            setState(() {
              _seed = DateTime.now().millisecondsSinceEpoch;
              _rediscover = [];
            });
          },
          child: ListView(padding: const EdgeInsets.only(bottom: 140), children: [
            LargeTitle(
              'Home',
              trailing: IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppTheme.accent),
                onPressed: () => AppNav.push(const SettingsScreen()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_greeting · ${lib.songs.length} songs on this phone',
                  style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 15)),
            ),
            PlayShuffleButtons(songs: lib.songs),
            _ShuffleHero(onTap: () => player.playSongs(lib.songs, shuffle: true)),
            if (recent.isNotEmpty) ...[
              SectionHeader('Recently Added',
                  onSeeAll: () => AppNav.push(AlbumsScreen(title: 'Recently Added', albums: lib.recentlyAdded))),
              _AlbumCarousel(albums: recent),
            ],
            if (topArtists.isNotEmpty) ...[
              SectionHeader('Your Artists', onSeeAll: () => AppNav.push(ArtistsScreen(artists: lib.artists))),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: topArtists.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) {
                    final a = topArtists[i];
                    return GestureDetector(
                      onTap: () => AppNav.push(ArtistScreen(artist: a)),
                      child: SizedBox(
                        width: 108,
                        child: Column(children: [
                          ArtistImage(a, size: 108),
                          const SizedBox(height: 8),
                          Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_rediscover.isNotEmpty) ...[
              const SectionHeader('Rediscover'),
              _AlbumCarousel(albums: _rediscover),
            ],
          ]),
        ),
      ),
    );
  }
}

class _AlbumCarousel extends StatelessWidget {
  final List<Album> albums;
  const _AlbumCarousel({required this.albums});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 212,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: albums.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) => AlbumCard(albums[i], width: 160),
        ),
      );
}

class _ShuffleHero extends StatelessWidget {
  final VoidCallback onTap;
  const _ShuffleHero({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6A3D), Color(0xFFE0336B), Color(0xFF7A2BD9)],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Your Mix',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Everything on your phone, shuffled.',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.play_arrow_rounded, color: Color(0xFFE0336B), size: 32),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
