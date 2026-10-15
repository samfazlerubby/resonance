import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/media_library.dart';
import '../../services/online_info.dart';
import '../../services/player_controller.dart';
import '../app_nav.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import 'artist_screen.dart';

class AlbumScreen extends StatefulWidget {
  final Album album;
  const AlbumScreen({super.key, required this.album});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late final Future<AlbumInfo?> _info =
      context.read<OnlineInfo>().album(widget.album.artist, widget.album.title);

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final player = context.read<PlayerController>();
    final lib = context.read<MediaLibrary>();
    final sub = AppTheme.secondaryText(context);
    final multiDisc = album.songs.map((s) => s.discNumber).toSet().length > 1;

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<AlbumInfo?>(
        future: _info,
        builder: (context, snap) {
          final info = snap.data;
          final year = album.year > 0 ? '${album.year}' : (info?.releaseDate?.split('-').first ?? '');
          final genre = info?.genres.isNotEmpty == true ? info!.genres.first : null;
          final meta = [if (genre != null) genre.toUpperCase(), if (year.isNotEmpty) year].join(' · ');

          return ListView(padding: const EdgeInsets.only(bottom: 140), children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(56, 4, 56, 18),
                child: Artwork.album(album, radius: 12, shadow: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                Text(album.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    final a = lib.artistByName(album.artist);
                    if (a != null) AppNav.push(ArtistScreen(artist: a));
                  },
                  child: Text(album.artist,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, color: AppTheme.accent)),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sub)),
                ],
              ]),
            ),
            PlayShuffleButtons(songs: album.songs),
            const Divider(indent: 20),
            for (var i = 0; i < album.songs.length; i++) ...[
              if (multiDisc && (i == 0 || album.songs[i].discNumber != album.songs[i - 1].discNumber))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text('Disc ${album.songs[i].discNumber}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: sub)),
                ),
              SongTile(
                song: album.songs[i],
                number: album.songs[i].trackNumber > 0 ? album.songs[i].trackNumber : i + 1,
                onTap: () => player.playSongs(album.songs, index: i),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (info?.releaseDate != null)
                  Text(_prettyDate(info!.releaseDate!), style: TextStyle(color: sub, fontSize: 14)),
                Text('${album.songs.length} song${album.songs.length == 1 ? '' : 's'}, '
                    '${formatLongDuration(album.duration)}',
                    style: TextStyle(color: sub, fontSize: 14)),
                if (info?.label != null && info!.label!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('℗ ${info!.label}', style: TextStyle(color: sub, fontSize: 12.5)),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  String _prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
