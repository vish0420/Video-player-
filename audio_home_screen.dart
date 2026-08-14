import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_item.dart';
import '../services/audio_scanner_service.dart';
import '../theme/season_gradients.dart';
import '../theme/theme_service.dart';
import 'audio_player_screen.dart';

class AudioHomeScreen extends StatefulWidget {
  const AudioHomeScreen({super.key});

  @override
  State<AudioHomeScreen> createState() => _AudioHomeScreenState();
}

class _AudioHomeScreenState extends State<AudioHomeScreen> {
  final _scanner = AudioScannerService();
  List<AudioItem> _audio = [];
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final granted = await _scanner.requestPermission();
    if (!granted) {
      setState(() {
        _denied = true;
        _loading = false;
      });
      return;
    }
    final audio = await _scanner.scanAudio();
    if (!mounted) return;
    setState(() {
      _audio = audio;
      _denied = false;
      _loading = false;
    });
  }

  String _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final gradient = theme.mode == AppThemeMode.gradient
        ? SeasonGradients.gradientFor(theme.activeSeason)
        : null;

    return Scaffold(
      extendBodyBehindAppBar: gradient != null,
      appBar: AppBar(
        title: const Text('My Audio'),
        backgroundColor: gradient != null ? Colors.transparent : null,
        elevation: gradient != null ? 0 : null,
        actions: [
          IconButton(onPressed: _scan, icon: const Icon(Icons.refresh)),
          if (gradient != null)
            PopupMenuButton<SeasonOverride>(
              icon: const Icon(Icons.eco_outlined),
              onSelected: theme.setSeasonOverride,
              itemBuilder: (_) => const [
                PopupMenuItem(value: SeasonOverride.auto, child: Text('Auto-detect')),
                PopupMenuItem(value: SeasonOverride.spring, child: Text('Spring')),
                PopupMenuItem(value: SeasonOverride.summer, child: Text('Summer')),
                PopupMenuItem(value: SeasonOverride.autumn, child: Text('Autumn')),
                PopupMenuItem(value: SeasonOverride.winter, child: Text('Winter')),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: gradient != null ? BoxDecoration(gradient: gradient) : null,
        child: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_denied) {
      return Center(
        child: FilledButton(
          onPressed: _scan,
          child: const Text('Grant audio access'),
        ),
      );
    }
    if (_audio.isEmpty) return const Center(child: Text('No audio files found.'));

    return RefreshIndicator(
      onRefresh: _scan,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _audio.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _audio[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.music_note_rounded)),
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${item.artist} • ${_time(item.duration)}'),
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AudioPlayerScreen(audio: item, playlist: _audio),
              ),
            ),
          );
        },
      ),
    );
  }
}
