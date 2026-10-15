import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/player_controller.dart';
import '../screens/now_playing_screen.dart';
import 'artwork.dart';

/// The floating "now playing" bar that sits above the tab bar.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: GestureDetector(
        onTap: () => NowPlayingScreen.open(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) NowPlayingScreen.open(context);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: dark ? const Color(0xCC2A2A2E) : const Color(0xE6F4F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dark ? Colors.white10 : Colors.black12, width: 0.5),
              ),
              child: Stack(children: [
                Row(children: [
                  const SizedBox(width: 8),
                  Hero(tag: 'now-playing-art', child: Artwork.song(song, size: 46, radius: 7)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: dark ? Colors.white60 : Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 34,
                    icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    onPressed: player.togglePlay,
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: const Icon(Icons.fast_forward_rounded),
                    onPressed: player.next,
                  ),
                  const SizedBox(width: 4),
                ]),
                // thin progress line along the bottom
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 0,
                  child: StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (_, snap) {
                      final total = song.duration.inMilliseconds;
                      final pos = snap.data?.inMilliseconds ?? 0;
                      return LinearProgressIndicator(
                        minHeight: 2,
                        value: total > 0 ? (pos / total).clamp(0.0, 1.0).toDouble() : 0.0,
                        backgroundColor: Colors.transparent,
                        color: dark ? Colors.white54 : Colors.black45,
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
