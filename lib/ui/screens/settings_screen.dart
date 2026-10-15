import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/media_library.dart';
import '../../services/online_info.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<int> _size = context.read<OnlineInfo>().cacheSizeBytes();

  @override
  Widget build(BuildContext context) {
    final online = context.watch<OnlineInfo>();
    final lib = context.read<MediaLibrary>();
    final sub = AppTheme.secondaryText(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        SwitchListTile(
          activeThumbColor: AppTheme.accent,
          title: const Text('Download info from the internet'),
          subtitle: Text(
            'Artist photos and bios, album covers and details, and lyrics. '
            'Anything already downloaded keeps working offline.',
            style: TextStyle(color: sub),
          ),
          value: online.enabled,
          onChanged: online.setEnabled,
        ),
        const Divider(),
        FutureBuilder<int>(
          future: _size,
          builder: (_, snap) => ListTile(
            title: const Text('Clear downloaded info'),
            subtitle: Text(
              snap.hasData ? 'Using ${(snap.data! / (1024 * 1024)).toStringAsFixed(1)} MB' : 'Calculating…',
              style: TextStyle(color: sub),
            ),
            trailing: const Icon(Icons.delete_outline_rounded),
            onTap: () async {
              await online.clearCache();
              setState(() => _size = online.cacheSizeBytes());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloaded info cleared')));
              }
            },
          ),
        ),
        ListTile(
          title: const Text('Rescan music on this phone'),
          subtitle: Text('Picks up songs you\'ve added since the app opened.', style: TextStyle(color: sub)),
          trailing: const Icon(Icons.refresh_rounded),
          onTap: () async {
            await lib.load();
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Found ${lib.songs.length} songs')));
            }
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Info sources: Deezer (photos, covers, release details), Wikipedia (biographies) '
            'and LRCLIB (lyrics). No account or API key needed.',
            style: TextStyle(color: sub, fontSize: 13),
          ),
        ),
      ]),
    );
  }
}
