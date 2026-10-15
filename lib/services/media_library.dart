import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

enum LibraryStatus { idle, loading, ready, noPermission, error }

/// Reads every song on the phone (via MainActivity.kt) and groups them
/// into albums and artists. Also extracts and caches embedded cover art.
class MediaLibrary extends ChangeNotifier {
  static const _channel = MethodChannel('resonance/media');

  LibraryStatus status = LibraryStatus.idle;
  String? errorMessage;

  List<Song> songs = [];
  List<Album> albums = [];
  List<Artist> artists = [];
  final Map<int, Song> _songsById = {};
  final Map<int, Album> _albumsById = {};
  final Map<String, Artist> _artistsByName = {};

  Song? songById(int id) => _songsById[id];
  Album? albumById(int id) => _albumsById[id];
  Artist? artistByName(String name) => _artistsByName[name.toLowerCase()];

  List<Album> get recentlyAdded {
    final list = [...albums]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return list;
  }

  /// Artists ordered by how many songs you have by them.
  List<Artist> get topArtists {
    final list = [...artists]..sort((a, b) => b.songs.length.compareTo(a.songs.length));
    return list;
  }

  Future<bool> requestPermission() async {
    // Android 13+ asks for "Music and audio"; older phones ask for "Storage".
    final results = await [Permission.audio, Permission.storage].request();
    return results.values.any((s) => s.isGranted || s.isLimited);
  }

  Future<void> load() async {
    status = LibraryStatus.loading;
    notifyListeners();
    try {
      if (!await requestPermission()) {
        status = LibraryStatus.noPermission;
        notifyListeners();
        return;
      }
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getSongs') ?? [];
      songs = raw.map(Song.fromMap).where((s) => s.duration.inSeconds >= 20).toList();
      _group();
      status = LibraryStatus.ready;
    } catch (e) {
      errorMessage = '$e';
      status = LibraryStatus.error;
    }
    notifyListeners();
  }

  void _group() {
    _songsById
      ..clear()
      ..addEntries(songs.map((s) => MapEntry(s.id, s)));

    final byAlbum = <int, List<Song>>{};
    for (final s in songs) {
      byAlbum.putIfAbsent(s.albumId, () => []).add(s);
    }
    albums = byAlbum.entries.map((e) {
      final list = e.value..sort((a, b) => a.track.compareTo(b.track));
      // Album artist = the most common artist on that album.
      final counts = <String, int>{};
      for (final s in list) {
        counts[s.artist] = (counts[s.artist] ?? 0) + 1;
      }
      final artist = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return Album(id: e.key, title: list.first.album, artist: artist, songs: list);
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _albumsById
      ..clear()
      ..addEntries(albums.map((a) => MapEntry(a.id, a)));

    final byArtist = <String, List<Song>>{};
    final display = <String, String>{};
    for (final s in songs) {
      final key = s.artist.toLowerCase();
      byArtist.putIfAbsent(key, () => []).add(s);
      display.putIfAbsent(key, () => s.artist);
    }
    _artistsByName.clear();
    artists = byArtist.entries.map((e) {
      final artistAlbums = albums
          .where((a) => a.artist.toLowerCase() == e.key ||
              a.songs.any((s) => s.artist.toLowerCase() == e.key))
          .toList()
        ..sort((a, b) => b.year.compareTo(a.year));
      final artist = Artist(name: display[e.key]!, albums: artistAlbums, songs: e.value);
      _artistsByName[e.key] = artist;
      return artist;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  // ---------------------------------------------------------------- artwork

  final LinkedHashMap<int, Uint8List?> _artMemory = LinkedHashMap();
  final Map<int, Future<Uint8List?>> _artPending = {};
  Directory? _artDir;

  Future<Directory> _artDirectory() async {
    if (_artDir != null) return _artDir!;
    final base = await getApplicationSupportDirectory();
    _artDir = Directory('${base.path}/artwork');
    await _artDir!.create(recursive: true);
    return _artDir!;
  }

  /// Cached file path for an album's cover. The notification uses this.
  Future<File> artFileFor(int albumId) async =>
      File('${(await _artDirectory()).path}/$albumId.jpg');

  Uint8List? cachedArtwork(int albumId) => _artMemory[albumId];
  bool hasCachedArtwork(int albumId) => _artMemory.containsKey(albumId);

  /// Embedded cover art for an album (null when the files have none).
  Future<Uint8List?> artworkFor(Album album) => _artwork(album.id, album.coverSong.id);
  Future<Uint8List?> artworkForSong(Song song) => _artwork(song.albumId, song.id);

  Future<Uint8List?> _artwork(int albumId, int songId) {
    if (_artMemory.containsKey(albumId)) return Future.value(_artMemory[albumId]);
    return _artPending.putIfAbsent(albumId, () async {
      Uint8List? bytes;
      try {
        final file = await artFileFor(albumId);
        final missingMarker = File('${file.path}.none');
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        } else if (!await missingMarker.exists()) {
          bytes = await _channel.invokeMethod<Uint8List>('getArtwork', {'id': songId, 'size': 600});
          if (bytes != null && bytes.isNotEmpty) {
            await file.writeAsBytes(bytes, flush: true);
          } else {
            bytes = null;
            await missingMarker.create();
          }
        }
      } catch (_) {
        bytes = null;
      }
      _artMemory[albumId] = bytes;
      if (_artMemory.length > 250) _artMemory.remove(_artMemory.keys.first);
      _artPending.remove(albumId);
      return bytes;
    });
  }

  /// Makes sure an album's cover is written to disk; returns the file or null.
  Future<File?> ensureArtFile(Song song) async {
    final bytes = await artworkForSong(song);
    if (bytes == null) return null;
    final f = await artFileFor(song.albumId);
    return await f.exists() ? f : null;
  }

  // ---------------------------------------------------------------- search

  ({List<Song> songs, List<Album> albums, List<Artist> artists}) search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return (songs: const <Song>[], albums: const <Album>[], artists: const <Artist>[]);
    bool hit(String s) => s.toLowerCase().contains(query);
    return (
      songs: songs.where((s) => hit(s.title) || hit(s.artist) || hit(s.album)).take(50).toList(),
      albums: albums.where((a) => hit(a.title) || hit(a.artist)).take(20).toList(),
      artists: artists.where((a) => hit(a.name)).take(20).toList(),
    );
  }
}
