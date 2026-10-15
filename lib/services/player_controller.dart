import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/models.dart';
import 'media_library.dart';

/// Owns the audio player and the play queue.
class PlayerController extends ChangeNotifier {
  PlayerController(this.library) {
    _init();
  }

  final MediaLibrary library;
  final AudioPlayer player = AudioPlayer();
  List<Song> queue = [];
  int? _index;

  Song? get current =>
      (_index != null && _index! >= 0 && _index! < queue.length) ? queue[_index!] : null;
  int? get currentIndex => _index;
  bool get isPlaying => player.playing;
  bool get shuffle => player.shuffleModeEnabled;
  LoopMode get loopMode => player.loopMode;

  /// Songs coming up next, in the order they'll actually play (shuffle-aware).
  List<Song> get upNext {
    final idx = _index;
    if (idx == null || queue.isEmpty) return const [];
    final order = player.shuffleModeEnabled
        ? (player.shuffleIndices)
        : List<int>.generate(queue.length, (i) => i);
    final pos = order.indexOf(idx);
    if (pos < 0) return const [];
    return order.skip(pos + 1).map((i) => queue[i]).toList();
  }

  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;

  final List<StreamSubscription> _subs = [];

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subs.add(player.currentIndexStream.listen((i) {
      _index = i;
      notifyListeners();
      _prefetchArt();
    }));
    _subs.add(player.playerStateStream.listen((_) => notifyListeners()));
    _subs.add(player.shuffleModeEnabledStream.listen((_) => notifyListeners()));
    _subs.add(player.loopModeStream.listen((_) => notifyListeners()));
  }

  /// Replace the queue with [songs] and start at [index].
  Future<void> playSongs(List<Song> songs, {int index = 0, bool shuffle = false}) async {
    if (songs.isEmpty) return;
    if (shuffle) index = Random().nextInt(songs.length);
    queue = List.of(songs);
    _index = index;
    notifyListeners();

    // Make sure the first song's cover is on disk before the notification shows.
    await library.ensureArtFile(songs[index]);
    final sources = <AudioSource>[];
    for (final s in queue) {
      sources.add(AudioSource.uri(Uri.parse(s.uri), tag: await _mediaItem(s)));
    }
    try {
      await player.setShuffleModeEnabled(shuffle);
      await player.setAudioSources(sources, initialIndex: index, initialPosition: Duration.zero);
      if (shuffle) await player.shuffle();
      player.play();
    } catch (e) {
      debugPrint('Playback failed: $e');
    }
  }

  Future<MediaItem> _mediaItem(Song s) async {
    final art = await library.artFileFor(s.albumId);
    return MediaItem(
      id: '${s.id}',
      title: s.title,
      artist: s.artist,
      album: s.album,
      duration: s.duration,
      artUri: Uri.file(art.path),
    );
  }

  /// Extract covers for the next few songs so the notification has them ready.
  void _prefetchArt() {
    for (final s in upNext.take(3)) {
      library.ensureArtFile(s);
    }
  }

  Future<void> playNext(Song song) => _insert(song, next: true);
  Future<void> addToQueue(Song song) => _insert(song, next: false);

  Future<void> _insert(Song song, {required bool next}) async {
    if (queue.isEmpty) return playSongs([song]);
    final pos = next ? (_index ?? -1) + 1 : queue.length;
    queue.insert(pos, song);
    await player.insertAudioSource(
        pos, AudioSource.uri(Uri.parse(song.uri), tag: await _mediaItem(song)));
    notifyListeners();
  }

  Future<void> jumpTo(Song song) async {
    final i = queue.indexOf(song);
    if (i >= 0) {
      await player.seek(Duration.zero, index: i);
      player.play();
    }
  }

  void togglePlay() => player.playing ? player.pause() : player.play();
  Future<void> next() => player.seekToNext();
  Future<void> previous() async {
    // Like most players: restart the song unless we're in its first 3 seconds.
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => player.seek(d);

  Future<void> toggleShuffle() async {
    final on = !player.shuffleModeEnabled;
    if (on) await player.shuffle();
    await player.setShuffleModeEnabled(on);
  }

  Future<void> cycleRepeat() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    await player.setLoopMode(order[(order.indexOf(player.loopMode) + 1) % order.length]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }
}
