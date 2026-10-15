import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/media_library.dart';
import '../../services/online_info.dart';
import '../../services/player_controller.dart';
import '../app_nav.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import 'album_screen.dart';
import 'artist_screen.dart';

enum _Panel { art, lyrics, queue }

/// Full-screen player: big cover on a blurred backdrop, scrubber, controls,
/// synced lyrics and the up-next queue.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
        child: child,
      ),
    ));
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  _Panel _panel = _Panel.art;
  final Map<int, Future<Lyrics?>> _lyrics = {};

  Future<Lyrics?> _lyricsFor(Song s) =>
      _lyrics.putIfAbsent(s.id, () => context.read<OnlineInfo>().lyrics(s));

  void _toggle(_Panel p) => setState(() => _panel = _panel == p ? _Panel.art : p);

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
          },
          child: Stack(fit: StackFit.expand, children: [
            _Backdrop(song: song),
            SafeArea(
              child: Column(children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3)),
                ),
                if (_panel != _Panel.art) _CompactHeader(song: song),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: switch (_panel) {
                      _Panel.art => _BigArt(key: const ValueKey('art'), song: song, playing: player.isPlaying),
                      _Panel.lyrics => _LyricsPanel(
                          key: ValueKey('lyrics-${song.id}'), song: song, lyrics: _lyricsFor(song)),
                      _Panel.queue => const _QueuePanel(key: ValueKey('queue')),
                    },
                  ),
                ),
                if (_panel == _Panel.art) _TitleRow(song: song),
                const _Scrubber(),
                const _Controls(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 6, 40, 14),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _ToggleIcon(
                      icon: Icons.lyrics_outlined,
                      active: _panel == _Panel.lyrics,
                      onTap: () => _toggle(_Panel.lyrics),
                    ),
                    _ToggleIcon(
                      icon: Icons.format_list_bulleted_rounded,
                      active: _panel == _Panel.queue,
                      onTap: () => _toggle(_Panel.queue),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final Song song;
  const _Backdrop({required this.song});

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Transform.scale(
          scale: 1.6,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.mirror),
            child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 300, height: 300, child: Artwork.song(song, radius: 0))),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x99000000), Color(0xCC000000)],
            ),
          ),
        ),
      ]);
}

class _BigArt extends StatelessWidget {
  final Song song;
  final bool playing;
  const _BigArt({super.key, required this.song, required this.playing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Center(
          child: AnimatedScale(
            scale: playing ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            child: Hero(tag: 'now-playing-art', child: Artwork.song(song, radius: 12, shadow: true)),
          ),
        ),
      );
}

class _TitleRow extends StatelessWidget {
  final Song song;
  const _TitleRow({required this.song});

  @override
  Widget build(BuildContext context) {
    final lib = context.read<MediaLibrary>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 16, 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white)),
            GestureDetector(
              onTap: () {
                final a = lib.artistByName(song.artist);
                if (a != null) AppNav.push(ArtistScreen(artist: a));
              },
              child: Text(song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, color: Colors.white70)),
            ),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          onSelected: (v) {
            if (v == 'album') {
              final a = lib.albumById(song.albumId);
              if (a != null) AppNav.push(AlbumScreen(album: a));
            } else {
              final a = lib.artistByName(song.artist);
              if (a != null) AppNav.push(ArtistScreen(artist: a));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'album', child: Text('Go to Album')),
            PopupMenuItem(value: 'artist', child: Text('Go to Artist')),
          ],
        ),
      ]),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final Song song;
  const _CompactHeader({required this.song});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
        child: Row(children: [
          Artwork.song(song, size: 56, radius: 6),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(song.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.white70)),
            ]),
          ),
        ]),
      );
}

class _Scrubber extends StatefulWidget {
  const _Scrubber();
  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (_, durSnap) {
        final total = durSnap.data ?? player.current?.duration ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (_, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final double max = total.inMilliseconds < 1 ? 1.0 : total.inMilliseconds.toDouble();
            final double value = (_dragValue ?? pos.inMilliseconds.toDouble()).clamp(0.0, max).toDouble();
            final shown = Duration(milliseconds: value.round());
            return Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
              child: Column(children: [
                Slider(
                  value: value,
                  max: max,
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    player.seek(Duration(milliseconds: v.round()));
                    setState(() => _dragValue = null);
                  },
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(formatDuration(shown), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  Text('-${formatDuration(total - shown)}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final repeatIcon = p.loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ToggleIcon(icon: Icons.shuffle_rounded, active: p.shuffle, onTap: p.toggleShuffle),
        IconButton(
          iconSize: 46,
          color: Colors.white,
          icon: const Icon(Icons.fast_rewind_rounded),
          onPressed: p.previous,
        ),
        IconButton(
          iconSize: 72,
          color: Colors.white,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              p.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(p.isPlaying),
            ),
          ),
          onPressed: p.togglePlay,
        ),
        IconButton(
          iconSize: 46,
          color: Colors.white,
          icon: const Icon(Icons.fast_forward_rounded),
          onPressed: p.next,
        ),
        _ToggleIcon(icon: repeatIcon, active: p.loopMode != LoopMode.off, onTap: p.cycleRepeat),
      ]),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleIcon({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 24, color: active ? Colors.white : Colors.white60),
        ),
      );
}

// ---------------------------------------------------------------- lyrics

class _LyricsPanel extends StatelessWidget {
  final Song song;
  final Future<Lyrics?> lyrics;
  const _LyricsPanel({super.key, required this.song, required this.lyrics});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<OnlineInfo>();
    return FutureBuilder<Lyrics?>(
      future: lyrics,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Colors.white54));
        }
        final l = snap.data;
        if (l == null) {
          return _message(
            Icons.lyrics_outlined,
            online.enabled
                ? 'No lyrics found for this song.\nIf you\'re offline, they\'ll download next time you\'re connected.'
                : 'Online info is turned off in Settings.',
          );
        }
        if (l.instrumental && !l.isSynced && l.plain.trim().isEmpty) {
          return _message(Icons.piano_rounded, 'Instrumental');
        }
        if (l.isSynced) return SyncedLyrics(lines: l.synced);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 60),
          child: Text(l.plain,
              style: const TextStyle(fontSize: 24, height: 1.45, fontWeight: FontWeight.w700, color: Colors.white)),
        );
      },
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: Colors.white38),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 15)),
          ]),
        ),
      );
}

/// Karaoke-style lyrics that follow the song; tap a line to jump there.
class SyncedLyrics extends StatefulWidget {
  final List<LyricLine> lines;
  const SyncedLyrics({super.key, required this.lines});

  @override
  State<SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<SyncedLyrics> {
  late final List<GlobalKey> _keys = List.generate(widget.lines.length, (_) => GlobalKey());
  final _scroll = ScrollController();
  int _current = -1;
  DateTime _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);

  int _indexAt(Duration pos) {
    var idx = -1;
    for (var i = 0; i < widget.lines.length; i++) {
      if (widget.lines[i].time <= pos + const Duration(milliseconds: 250)) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _follow(int idx) {
    if (idx < 0 || idx == _current) return;
    _current = idx;
    if (DateTime.now().difference(_userScrolledAt) < const Duration(seconds: 4)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[idx].currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.3, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _userScrolledAt = DateTime.now();
        return false;
      },
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.08, 0.85, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (_, snap) {
            final idx = _indexAt(snap.data ?? Duration.zero);
            _follow(idx);
            return SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 260),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < widget.lines.length; i++)
                  GestureDetector(
                    key: _keys[i],
                    onTap: () {
                      _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);
                      player.seek(widget.lines[i].time);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: i == idx ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        ),
                        child: Text(widget.lines[i].text.isEmpty ? '♪' : widget.lines[i].text),
                      ),
                    ),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- queue

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final next = player.upNext;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(28, 18, 28, 6),
        child: Text('Playing Next', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      Expanded(
        child: next.isEmpty
            ? const Center(child: Text('Nothing up next', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: next.length,
                itemBuilder: (_, i) {
                  final s = next[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                    leading: Artwork.song(s, size: 44, radius: 5),
                    title: Text(s.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(s.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
                    onTap: () => player.jumpTo(s),
                  );
                },
              ),
      ),
    ]);
  }
}
