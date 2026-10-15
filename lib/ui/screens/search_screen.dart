import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_library.dart';
import '../../services/player_controller.dart';
import '../widgets/common.dart';
import 'list_screens.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibrary>();
    final player = context.read<PlayerController>();
    final r = lib.search(_query);
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const SliverToBoxAdapter(child: LargeTitle('Search')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Artists, Songs, Albums',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.cancel_rounded),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: surface,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            if (_query.trim().isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_rounded,
                  title: 'Search your music',
                  message: 'Find songs, albums and artists stored on this phone.',
                ),
              )
            else if (r.songs.isEmpty && r.albums.isEmpty && r.artists.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.sentiment_neutral_rounded,
                  title: 'No Results',
                  message: 'Nothing matches “${_query.trim()}”.',
                ),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate([
                  if (r.artists.isNotEmpty) ...[
                    const SectionHeader('Artists'),
                    for (final a in r.artists) ArtistTile(artist: a),
                  ],
                  if (r.albums.isNotEmpty) ...[
                    const SectionHeader('Albums'),
                    SizedBox(
                      height: 212,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: r.albums.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => AlbumCard(r.albums[i], width: 160),
                      ),
                    ),
                  ],
                  if (r.songs.isNotEmpty) ...[
                    const SectionHeader('Songs'),
                    for (var i = 0; i < r.songs.length; i++)
                      SongTile(song: r.songs[i], onTap: () => player.playSongs(r.songs, index: i)),
                  ],
                  const SizedBox(height: 140),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
