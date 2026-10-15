import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/media_library.dart';
import '../../services/player_controller.dart';
import '../app_nav.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../theme.dart';
import 'artwork.dart';

/// A row in any song list.
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool showArt;
  final int? number; // track number instead of artwork (album pages)

  const SongTile({super.key, required this.song, required this.onTap, this.showArt = true, this.number});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final isCurrent = player.current?.id == song.id;
    final sub = AppTheme.secondaryText(context);
    Widget leading;
    if (number != null) {
      leading = SizedBox(
        width: 28,
        child: isCurrent
            ? const Icon(Icons.graphic_eq_rounded, color: AppTheme.accent, size: 20)
            : Text('$number', textAlign: TextAlign.center, style: TextStyle(color: sub, fontSize: 15)),
      );
    } else {
      leading = Stack(children: [
        Artwork.song(song, size: 48, radius: 6),
        if (isCurrent)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 22),
          ),
      ]);
    }
    return InkWell(
      onTap: onTap,
      onLongPress: () => showSongActions(context, song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCurrent ? AppTheme.accent : null,
                    fontWeight: FontWeight.w500,
                  )),
              if (number == null)
                Text(song.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: sub)),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: sub),
            onPressed: () => showSongActions(context, song),
          ),
        ]),
      ),
    );
  }
}

/// Long-press / "…" menu for a song.
void showSongActions(BuildContext context, Song song) {
  final player = context.read<PlayerController>();
  final lib = context.read<MediaLibrary>();
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Artwork.song(song, size: 48),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${song.artist} · ${song.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.playlist_play_rounded),
          title: const Text('Play Next'),
          onTap: () {
            Navigator.pop(sheet);
            player.playNext(song);
          },
        ),
        ListTile(
          leading: const Icon(Icons.queue_music_rounded),
          title: const Text('Add to Queue'),
          onTap: () {
            Navigator.pop(sheet);
            player.addToQueue(song);
          },
        ),
        ListTile(
          leading: const Icon(Icons.album_rounded),
          title: const Text('Go to Album'),
          onTap: () {
            Navigator.pop(sheet);
            final album = lib.albumById(song.albumId);
            if (album != null) AppNav.push(AlbumScreen(album: album));
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_rounded),
          title: const Text('Go to Artist'),
          onTap: () {
            Navigator.pop(sheet);
            final artist = lib.artistByName(song.artist);
            if (artist != null) AppNav.push(ArtistScreen(artist: artist));
          },
        ),
      ]),
    ),
  );
}

/// The pair of "Play" / "Shuffle" pill buttons at the top of lists.
class PlayShuffleButtons extends StatelessWidget {
  final List<Song> songs;
  const PlayShuffleButtons({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget pill(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: AppTheme.accent,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: songs.isEmpty ? null : onTap,
            icon: Icon(icon),
            label: Text(label),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        pill(Icons.play_arrow_rounded, 'Play', () => player.playSongs(songs)),
        const SizedBox(width: 14),
        pill(Icons.shuffle_rounded, 'Shuffle', () => player.playSongs(songs, shuffle: true)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader(this.title, {super.key, this.onSeeAll});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 12, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: AppTheme.sectionTitle(context))),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See All', style: TextStyle(fontSize: 16, color: AppTheme.accent)),
            ),
        ]),
      );
}

/// Square album card used in grids and carousels.
class AlbumCard extends StatelessWidget {
  final Album album;
  final double? width;
  const AlbumCard(this.album, {super.key, this.width});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => AppNav.push(AlbumScreen(album: album)),
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Artwork.album(album, radius: 10),
            const SizedBox(height: 7),
            Text(album.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
            Text(album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: AppTheme.secondaryText(context))),
          ]),
        ),
      );
}

class LargeTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const LargeTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
        child: Row(children: [
          Expanded(child: Text(text, style: AppTheme.largeTitle(context))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppTheme.sectionTitle(context)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}
