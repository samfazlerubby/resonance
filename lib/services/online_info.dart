import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Fetches artist photos & bios, album covers & details, and lyrics from free,
/// key-less public services, then keeps everything on the phone so it still
/// shows when you're offline:
///   • Deezer public API   – artist photos, album covers, release info
///   • Wikipedia REST API   – artist biographies
///   • LRCLIB               – synced (karaoke-style) and plain lyrics
///
/// Every call fails quietly (returns null) when there's no internet.
class OnlineInfo extends ChangeNotifier {
  static const _ua = 'Resonance/1.0 (personal Android music player)';
  static const _retryMissesAfter = Duration(days: 7);

  bool enabled = true;
  Directory? _dir;
  final Map<String, Future<Map<String, dynamic>?>> _inflight = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool('online_enabled') ?? true;
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/online');
    await _dir!.create(recursive: true);
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('online_enabled', value);
    notifyListeners();
  }

  Future<int> cacheSizeBytes() async {
    if (_dir == null || !await _dir!.exists()) return 0;
    var total = 0;
    await for (final f in _dir!.list(recursive: true)) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    if (_dir != null && await _dir!.exists()) {
      await _dir!.delete(recursive: true);
      await _dir!.create(recursive: true);
    }
    notifyListeners();
  }

  String _hash(String s) => md5.convert(utf8.encode(s.toLowerCase())).toString();

  // ------------------------------------------------------------ JSON cache

  Future<Map<String, dynamic>?> _readCache(String key) async {
    final f = File('${_dir!.path}/${_hash(key)}.json');
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (j['miss'] == true) {
        final at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
        // Retry earlier "not found" results now and then.
        if (DateTime.now().difference(at) > _retryMissesAfter) return null;
      }
      return j;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, Map<String, dynamic>? data) async {
    final f = File('${_dir!.path}/${_hash(key)}.json');
    final payload = data == null
        ? {'miss': true, 'at': DateTime.now().millisecondsSinceEpoch}
        : {'data': data};
    await f.writeAsString(jsonEncode(payload));
  }

  /// Cache wrapper: returns cached data; otherwise fetches (if online is on).
  /// Network failures are not cached, so they're retried next time.
  Future<Map<String, dynamic>?> _cached(
      String key, Future<Map<String, dynamic>?> Function() fetch) {
    return (_inflight[key] ??= () async {
      try {
        if (_dir == null) await init();
        final hit = await _readCache(key);
        if (hit != null) return hit['data'] as Map<String, dynamic>?;
        if (!enabled) return null;
        final fresh = await fetch();
        await _writeCache(key, fresh);
        return fresh;
      } on _Offline {
        return null;
      } catch (_) {
        return null;
      } finally {
        // ignore: unawaited_futures
        Future.microtask(() => _inflight.remove(key));
      }
    }());
  }

  Future<dynamic> _getJson(Uri url, {bool allow404 = false}) async {
    http.Response res;
    try {
      res = await http
          .get(url, headers: {'User-Agent': _ua, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // No connection, DNS failure, timeout...
      throw _Offline();
    }
    if (res.statusCode == 404 && allow404) return null;
    if (res.statusCode >= 500 || res.statusCode == 429) throw _Offline();
    if (res.statusCode != 200) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Downloads an image once and keeps it on the phone.
  Future<File?> cachedImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (_dir == null) await init();
    final f = File('${_dir!.path}/img_${_hash(url)}.jpg');
    if (await f.exists()) return f;
    if (!enabled) return null;
    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      await f.writeAsBytes(res.bodyBytes, flush: true);
      return f;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- artist

  Future<ArtistInfo?> artist(String name) async {
    if (name == 'Unknown Artist') return null;
    final data = await _cached('artist:$name', () async {
      final search = await _getJson(Uri.https('api.deezer.com', '/search/artist', {'q': name, 'limit': '5'}));
      final list = (search is Map ? search['data'] as List? : null) ?? const [];
      Map? match;
      for (final a in list) {
        if ((a['name'] as String?)?.toLowerCase() == name.toLowerCase()) {
          match = a as Map;
          break;
        }
      }
      match ??= list.isNotEmpty ? list.first as Map : null;
      final bio = await _wikipediaBio(name);
      if (match == null && bio == null) return null;
      final picture = match?['picture_xl'] as String?;
      return ArtistInfo(
        // Deezer returns a generic silhouette when it has no photo; skip it.
        imageUrl: (picture != null && !picture.contains('/artist//')) ? picture : null,
        fans: (match?['nb_fan'] as num?)?.toInt(),
        bio: bio,
      ).toJson();
    });
    return data == null ? null : ArtistInfo.fromJson(data);
  }

  Future<String?> _wikipediaBio(String name) async {
    final candidates = [
      '$name (band)', '$name (musician)', '$name (singer)', '$name (rapper)', name,
    ];
    for (final title in candidates) {
      final j = await _getJson(
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/'
            '${Uri.encodeComponent(title.replaceAll(' ', '_'))}'),
        allow404: true,
      );
      if (j is! Map) continue;
      if (j['type'] == 'disambiguation') continue;
      final extract = (j['extract'] as String?)?.trim();
      final desc = ((j['description'] as String?) ?? '').toLowerCase();
      final looksMusical = RegExp(r'band|singer|musician|rapper|songwriter|group|composer|dj|producer|artist|duo|orchestra|vocalist')
          .hasMatch('$desc ${extract ?? ''}'.toLowerCase());
      if (extract != null && extract.isNotEmpty && looksMusical) return extract;
    }
    return null;
  }

  // ----------------------------------------------------------------- album

  Future<AlbumInfo?> album(String artist, String title) async {
    if (title == 'Unknown Album') return null;
    final data = await _cached('album:$artist|$title', () async {
      final q = artist == 'Unknown Artist' ? 'album:"$title"' : 'artist:"$artist" album:"$title"';
      final search = await _getJson(Uri.https('api.deezer.com', '/search/album', {'q': q, 'limit': '1'}));
      final list = (search is Map ? search['data'] as List? : null) ?? const [];
      if (list.isEmpty) return null;
      final hit = list.first as Map;
      final details = await _getJson(Uri.https('api.deezer.com', '/album/${hit['id']}'));
      final genres = <String>[];
      if (details is Map) {
        for (final g in ((details['genres'] as Map?)?['data'] as List?) ?? const []) {
          genres.add(g['name'] as String);
        }
      }
      return AlbumInfo(
        coverUrl: hit['cover_xl'] as String?,
        releaseDate: details is Map ? details['release_date'] as String? : null,
        label: details is Map ? details['label'] as String? : null,
        genres: genres,
      ).toJson();
    });
    return data == null ? null : AlbumInfo.fromJson(data);
  }

  // ---------------------------------------------------------------- lyrics

  Future<Lyrics?> lyrics(Song song) async {
    final data = await _cached('lyrics:${song.artist}|${song.title}|${song.duration.inSeconds}', () async {
      final artist = song.artist == 'Unknown Artist' ? '' : song.artist;
      Map? hit;
      // 1) exact match on title/artist/album/duration
      final exact = await _getJson(
        Uri.https('lrclib.net', '/api/get', {
          'track_name': song.title,
          'artist_name': artist,
          'album_name': song.album,
          'duration': '${song.duration.inSeconds}',
        }),
        allow404: true,
      );
      if (exact is Map && exact['id'] != null) hit = exact;
      // 2) looser search, preferring a result whose length is close
      if (hit == null) {
        final results = await _getJson(Uri.https('lrclib.net', '/api/search', {
          'track_name': song.title,
          if (artist.isNotEmpty) 'artist_name': artist,
        }));
        if (results is List && results.isNotEmpty) {
          final secs = song.duration.inSeconds;
          final sorted = results.cast<Map>().toList()
            ..sort((a, b) => _score(a, secs).compareTo(_score(b, secs)));
          hit = sorted.first;
        }
      }
      if (hit == null) return null;
      return {
        'synced': hit['syncedLyrics'],
        'plain': hit['plainLyrics'],
        'instrumental': hit['instrumental'] == true,
      };
    });
    if (data == null) return null;
    final lyr = Lyrics(
      synced: Lyrics.parseLrc((data['synced'] as String?) ?? ''),
      plain: (data['plain'] as String?) ?? '',
      instrumental: data['instrumental'] == true,
    );
    return lyr.isEmpty ? null : lyr;
  }
}

/// Lower is better: close in length, and synced lyrics preferred.
num _score(Map r, int secs) =>
    (((r['duration'] as num?) ?? 0) - secs).abs() + (r['syncedLyrics'] != null ? 0 : 4);

class _Offline implements Exception {}
