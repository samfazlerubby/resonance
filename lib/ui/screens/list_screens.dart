import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/player_controller.dart';
import '../app_nav.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import 'artist_screen.dart';

class SongsScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;
  const SongsScreen({super.key, required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 140),
        itemCount: songs.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return PlayShuffleButtons(songs: songs);
          return SongTile(song: songs[i - 1], onTap: () => player.playSongs(songs, index: i - 1));
        },
      ),
    );
  }
}

class AlbumsScreen extends StatelessWidget {
  final String title;
  final List<Album> albums;
  const AlbumsScreen({super.key, required this.title, required this.albums});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AlbumGrid(albums: albums, padding: const EdgeInsets.fromLTRB(20, 8, 20, 140)),
      );
}

class AlbumGrid extends StatelessWidget {
  final List<Album> albums;
  final EdgeInsets padding;
  final bool shrinkWrap;
  const AlbumGrid({super.key, required this.albums, required this.padding, this.shrinkWrap = false});

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 18,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemCount: albums.length,
        itemBuilder: (_, i) => AlbumCard(albums[i]),
      );
}

class ArtistsScreen extends StatelessWidget {
  final List<Artist> artists;
  const ArtistsScreen({super.key, required this.artists});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Artists')),
        body: ListView.builder(
          padding: const EdgeInsets.only(bottom: 140),
          itemCount: artists.length,
          itemBuilder: (_, i) => ArtistTile(artist: artists[i]),
        ),
      );
}

class ArtistTile extends StatelessWidget {
  final Artist artist;
  const ArtistTile({super.key, required this.artist});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: ArtistImage(artist, size: 50),
        title: Text(artist.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${artist.albums.length} album${artist.albums.length == 1 ? '' : 's'} · '
          '${artist.songs.length} song${artist.songs.length == 1 ? '' : 's'}',
          style: TextStyle(color: AppTheme.secondaryText(context)),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryText(context)),
        onTap: () => AppNav.push(ArtistScreen(artist: artist)),
      );
}
