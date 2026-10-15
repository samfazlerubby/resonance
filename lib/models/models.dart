/// Plain data classes for the music library.
library;

class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final Duration duration;
  final int track; // MediaStore stores disc*1000 + track
  final int year;
  final DateTime dateAdded;
  final String uri; // content:// URI the player can open

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.track,
    required this.year,
    required this.dateAdded,
    required this.uri,
  });

  int get trackNumber => track % 1000;
  int get discNumber => track ~/ 1000;

  factory Song.fromMap(Map<dynamic, dynamic> m) {
    String clean(Object? v, String fallback) {
      final s = (v as String?)?.trim() ?? '';
      if (s.isEmpty || s == '<unknown>') return fallback;
      return s;
    }

    return Song(
      id: (m['id'] as num).toInt(),
      title: clean(m['title'], 'Unknown Title'),
      artist: clean(m['artist'], 'Unknown Artist'),
      album: clean(m['album'], 'Unknown Album'),
      albumId: (m['albumId'] as num?)?.toInt() ?? 0,
      duration: Duration(milliseconds: (m['duration'] as num?)?.toInt() ?? 0),
      track: (m['track'] as num?)?.toInt() ?? 0,
      year: (m['year'] as num?)?.toInt() ?? 0,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
          ((m['dateAdded'] as num?)?.toInt() ?? 0) * 1000),
      uri: m['uri'] as String,
    );
  }
}

class Album {
  final int id;
  final String title;
  final String artist;
  final List<Song> songs;

  Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.songs,
  });

  int get year => songs.map((s) => s.year).fold(0, (a, b) => b > a ? b : a);
  Duration get duration =>
      songs.fold(Duration.zero, (sum, s) => sum + s.duration);
  DateTime get dateAdded => songs
      .map((s) => s.dateAdded)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  /// The song whose embedded cover represents this album.
  Song get coverSong => songs.first;
}

class Artist {
  final String name;
  final List<Album> albums;
  final List<Song> songs;

  Artist({required this.name, required this.albums, required this.songs});
}

/// One line of time-synced lyrics.
class LyricLine {
  final Duration time;
  final String text;
  const LyricLine(this.time, this.text);
}

class Lyrics {
  final List<LyricLine> synced; // empty when only plain lyrics exist
  final String plain;
  final bool instrumental;

  const Lyrics({this.synced = const [], this.plain = '', this.instrumental = false});

  bool get isSynced => synced.isNotEmpty;
  bool get isEmpty => synced.isEmpty && plain.trim().isEmpty && !instrumental;

  /// Parses LRC text such as "[01:02.35] some words".
  static List<LyricLine> parseLrc(String lrc) {
    final tag = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
    final lines = <LyricLine>[];
    for (final raw in lrc.split('\n')) {
      final matches = tag.allMatches(raw).toList();
      if (matches.isEmpty) continue;
      final text = raw.substring(matches.last.end).trim();
      for (final m in matches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = double.parse(m.group(2)!);
        lines.add(LyricLine(
          Duration(milliseconds: ((minutes * 60 + seconds) * 1000).round()),
          text,
        ));
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}

/// Info downloaded from the internet about an artist.
class ArtistInfo {
  final String? imageUrl;
  final String? bio;
  final int? fans;
  const ArtistInfo({this.imageUrl, this.bio, this.fans});

  Map<String, dynamic> toJson() => {'imageUrl': imageUrl, 'bio': bio, 'fans': fans};
  factory ArtistInfo.fromJson(Map<String, dynamic> j) => ArtistInfo(
        imageUrl: j['imageUrl'] as String?,
        bio: j['bio'] as String?,
        fans: (j['fans'] as num?)?.toInt(),
      );
}

/// Info downloaded from the internet about an album.
class AlbumInfo {
  final String? coverUrl;
  final String? releaseDate;
  final String? label;
  final List<String> genres;
  const AlbumInfo({this.coverUrl, this.releaseDate, this.label, this.genres = const []});

  Map<String, dynamic> toJson() =>
      {'coverUrl': coverUrl, 'releaseDate': releaseDate, 'label': label, 'genres': genres};
  factory AlbumInfo.fromJson(Map<String, dynamic> j) => AlbumInfo(
        coverUrl: j['coverUrl'] as String?,
        releaseDate: j['releaseDate'] as String?,
        label: j['label'] as String?,
        genres: ((j['genres'] as List?) ?? const []).cast<String>(),
      );
}
