import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/online_info.dart';
import '../../services/player_controller.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import 'list_screens.dart';

class ArtistScreen extends StatefulWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  ArtistInfo? _info;
  File? _photo;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final online = context.read<OnlineInfo>();
    final info = await online.artist(widget.artist.name);
    final photo = await online.cachedImage(info?.imageUrl);
    if (mounted) {
      setState(() {
        _info = info;
        _photo = photo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final player = context.read<PlayerController>();
    final sub = AppTheme.secondaryText(context);
    final width = MediaQuery.sizeOf(context).width;
    final topSongs = artist.songs.take(5).toList();

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: width * 0.85,
          backgroundColor: const Color(0xFF111114),
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16, end: 80),
            title: Text(artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white)),
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(fit: StackFit.expand, children: [
              if (_photo != null)
                Image.file(_photo!, fit: BoxFit.cover)
              else if (artist.albums.isNotEmpty)
                Artwork.album(artist.albums.first, radius: 0)
              else
                ArtPlaceholder(seed: artist.name, icon: Icons.person_rounded),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55000000), Colors.transparent, Color(0xAA000000)],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FloatingActionButton.small(
                heroTag: null,
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                onPressed: () => player.playSongs(artist.songs, shuffle: true),
                child: const Icon(Icons.shuffle_rounded),
              ),
            ),
          ],
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (_info?.fans != null && _info!.fans! > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text('${_compact(_info!.fans!)} fans worldwide', style: TextStyle(color: sub)),
              ),
            SectionHeader('Top Songs',
                onSeeAll: artist.songs.length > 5
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SongsScreen(title: artist.name, songs: artist.songs)))
                    : null),
            for (var i = 0; i < topSongs.length; i++)
              SongTile(song: topSongs[i], onTap: () => player.playSongs(artist.songs, index: i)),
            if (artist.albums.isNotEmpty) ...[
              const SectionHeader('Albums'),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: artist.albums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => AlbumCard(artist.albums[i], width: 160),
                ),
              ),
            ],
            if (_info?.bio != null) ...[
              SectionHeader('About ${artist.name}'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        alignment: Alignment.topCenter,
                        child: Text(
                          _info!.bio!,
                          maxLines: _bioExpanded ? null : 4,
                          overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_bioExpanded ? 'Less' : 'More',
                          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('From Wikipedia', style: TextStyle(fontSize: 11.5, color: sub)),
                    ]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 140),
          ]),
        ),
      ]),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}
