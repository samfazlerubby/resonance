import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/media_library.dart';
import '../../services/online_info.dart';

/// Album cover. Uses the art embedded in the music file first; if there is
/// none it downloads the cover online (and keeps it), otherwise shows a
/// tinted placeholder.
class Artwork extends StatefulWidget {
  final int albumId;
  final int songId;
  final String albumTitle;
  final String artist;
  final double? size;
  final double radius;
  final bool shadow;

  Artwork.album(Album a, {super.key, this.size, this.radius = 8, this.shadow = false})
      : albumId = a.id,
        songId = a.coverSong.id,
        albumTitle = a.title,
        artist = a.artist;

  Artwork.song(Song s, {super.key, this.size, this.radius = 6, this.shadow = false})
      : albumId = s.albumId,
        songId = s.id,
        albumTitle = s.album,
        artist = s.artist;

  @override
  State<Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<Artwork> {
  Uint8List? _bytes;
  File? _file;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(Artwork old) {
    super.didUpdateWidget(old);
    if (old.albumId != widget.albumId) {
      _bytes = null;
      _file = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final lib = context.read<MediaLibrary>();
    final online = context.read<OnlineInfo>();
    final id = widget.albumId;
    if (lib.hasCachedArtwork(id)) {
      _bytes = lib.cachedArtwork(id);
    } else {
      final song = lib.songById(widget.songId);
      _bytes = song == null ? null : await lib.artworkForSong(song);
    }
    if (_bytes == null) {
      final info = await online.album(widget.artist, widget.albumTitle);
      _file = await online.cachedImage(info?.coverUrl);
    }
    if (mounted && id == widget.albumId) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_bytes != null) {
      child = Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (_file != null) {
      child = Image.file(_file!, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      child = ArtPlaceholder(seed: widget.albumTitle, faded: _loading);
    }
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: widget.shadow
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey('${_bytes != null}${_file != null}'), child: child),
          ),
        ),
      ),
    );
  }
}

class ArtPlaceholder extends StatelessWidget {
  final String seed;
  final bool faded;
  final IconData icon;
  const ArtPlaceholder({super.key, required this.seed, this.faded = false, this.icon = Icons.music_note_rounded});

  @override
  Widget build(BuildContext context) {
    final hue = (seed.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFFFF) % 360).toDouble();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c1 = HSLColor.fromAHSL(1, hue, 0.35, dark ? 0.22 : 0.80).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.35, dark ? 0.14 : 0.70).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
      ),
      child: LayoutBuilder(
        builder: (_, box) => Center(
          child: Icon(icon,
              size: box.maxWidth * 0.4,
              color: (dark ? Colors.white : Colors.black).withValues(alpha: faded ? 0.12 : 0.3)),
        ),
      ),
    );
  }
}

/// Round artist photo, downloaded online; falls back to one of their covers.
class ArtistImage extends StatefulWidget {
  final Artist artist;
  final double size;
  const ArtistImage(this.artist, {super.key, this.size = 56});

  @override
  State<ArtistImage> createState() => _ArtistImageState();
}

class _ArtistImageState extends State<ArtistImage> {
  File? _file;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final online = context.read<OnlineInfo>();
    final info = await online.artist(widget.artist.name);
    final f = await online.cachedImage(info?.imageUrl);
    if (mounted) setState(() {
      _file = f;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_file != null) {
      child = Image.file(_file!, fit: BoxFit.cover);
    } else if (_done && widget.artist.albums.isNotEmpty) {
      child = Artwork.album(widget.artist.albums.first, radius: 0);
    } else {
      child = ArtPlaceholder(seed: widget.artist.name, icon: Icons.person_rounded, faded: !_done);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(child: child),
    );
  }
}
