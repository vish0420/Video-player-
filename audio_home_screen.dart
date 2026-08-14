import 'package:flutter/material.dart';

import 'audio_item.dart';
import 'audio_player_screen.dart';
import 'audio_scanner_service.dart';

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
      setState(() { _denied = true; _loading = false; });
      return;
    }
    final audio = await _scanner.scanAudio();
    if (!mounted) return;
    setState(() { _audio = audio; _denied = false; _loading = false; });
  }

  String _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Audio'),
        actions: [IconButton(onPressed: _scan, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denied
              ? Center(child: FilledButton(onPressed: _scan, child: const Text('Grant audio access')))
              : _audio.isEmpty
                  ? const Center(child: Text('No audio files found.'))
                  : RefreshIndicator(
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
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AudioPlayerScreen(audio: item, playlist: _audio))),
                          );
                        },
                      ),
                    ),
    );
  }
}
