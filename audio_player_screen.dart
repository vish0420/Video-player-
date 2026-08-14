import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'models/audio_item.dart';

class AudioPlayerScreen extends StatefulWidget {
  final AudioItem audio;
  final List<AudioItem> playlist;

  const AudioPlayerScreen({super.key, required this.audio, required this.playlist});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final AudioPlayer _player;
  late int _index;
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  bool _shuffle = false;
  bool _repeat = false;

  AudioItem get current => widget.playlist[_index];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _index = widget.playlist.indexWhere((a) => a.asset.id == widget.audio.asset.id);
    if (_index < 0) _index = 0;
    _openCurrent();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        _next();
      }
    });
  }

  Future<void> _openCurrent() async {
    final path = await current.resolvePath();
    if (path == null || !mounted) return;
    try {
      final source = AudioSource.file(
        path,
        tag: MediaItem(
          id: path,
          title: current.title,
          artist: current.artist,
          album: current.album,
          duration: current.duration,
        ),
      );
      await _player.setAudioSource(source);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This audio file could not be decoded on this device.')),
        );
      }
    }
  }

  Future<void> _next() async {
    if (widget.playlist.isEmpty) return;
    if (_shuffle && widget.playlist.length > 1) {
      _index = (_index + 1 + DateTime.now().millisecondsSinceEpoch % (widget.playlist.length - 1)) % widget.playlist.length;
    } else if (_index < widget.playlist.length - 1) {
      _index++;
    } else if (_repeat) {
      _index = 0;
    } else {
      await _player.pause();
      return;
    }
    setState(() {});
    await _openCurrent();
  }

  Future<void> _previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_index > 0) {
      setState(() => _index--);
      await _openCurrent();
    }
  }

  void _sleep(Duration duration) {
    _sleepTimer?.cancel();
    if (duration == Duration.zero) {
      setState(() => _sleepRemaining = null);
      return;
    }
    setState(() => _sleepRemaining = duration);
    _sleepTimer = Timer(duration, () async {
      await _player.pause();
      if (mounted) setState(() => _sleepRemaining = null);
    });
  }

  Future<void> _showSleepTimer() async {
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sleep timer'), subtitle: Text('Stop playback automatically')),
            for (final m in [15, 30, 45, 60, 90])
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$m minutes'),
                onTap: () => Navigator.pop(context, Duration(minutes: m)),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Off'),
              onTap: () => Navigator.pop(context, Duration.zero),
            ),
          ],
        ),
      ),
    );
    if (choice != null) _sleep(choice);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
        actions: [
          IconButton(
            tooltip: 'Playlist',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => _PlaylistSheet(
                items: widget.playlist,
                selected: _index,
                onSelect: (i) {
                  Navigator.pop(context);
                  setState(() => _index = i);
                  _openCurrent();
                },
              ),
            ),
          ),
          IconButton(tooltip: 'Sleep timer', icon: const Icon(Icons.bedtime_outlined), onPressed: _showSleepTimer),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -250) {
            _next();
          } else if ((d.primaryVelocity ?? 0) > 250) {
            _previous();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF182848), Color(0xFF4B6CB7)],
                    ),
                  ),
                  child: const Icon(Icons.music_note_rounded, size: 110, color: Colors.white),
                ),
                const SizedBox(height: 28),
                Text(current.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(current.artist, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, p) => StreamBuilder<Duration?>(
                    stream: _player.durationStream,
                    builder: (_, d) {
                      final pos = p.data ?? Duration.zero;
                      final dur = d.data ?? current.duration;
                      final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                      final value = pos.inMilliseconds.clamp(0, max.toInt()).toDouble();
                      return Column(
                        children: [
                          Slider(value: value, min: 0, max: max, onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt()))),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(pos)), Text(_fmt(dur))]),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (_, s) {
                    final playing = s.data?.playing ?? false;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(iconSize: 34, onPressed: _previous, icon: const Icon(Icons.skip_previous_rounded)),
                        IconButton(iconSize: 34, onPressed: () => _player.seek(_player.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10_rounded)),
                        IconButton(iconSize: 72, onPressed: () => playing ? _player.pause() : _player.play(), icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded)),
                        IconButton(iconSize: 34, onPressed: () => _player.seek(_player.position + const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded)),
                        IconButton(iconSize: 34, onPressed: _next, icon: const Icon(Icons.skip_next_rounded)),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(tooltip: 'Shuffle', icon: Icon(_shuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded), onPressed: () => setState(() => _shuffle = !_shuffle)),
                    IconButton(tooltip: 'Repeat', icon: Icon(_repeat ? Icons.repeat_on_rounded : Icons.repeat_rounded), onPressed: () => setState(() => _repeat = !_repeat)),
                    if (_sleepRemaining != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Sleep ${_fmt(_sleepRemaining!)}')),
                  ],
                ),
                const Spacer(),
                const Text('Swipe left/right to change tracks', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSheet extends StatelessWidget {
  final List<AudioItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  const _PlaylistSheet({required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: items.length,
        itemBuilder: (_, i) => ListTile(
          selected: i == selected,
          leading: Icon(i == selected ? Icons.graphic_eq : Icons.music_note_outlined),
          title: Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(items[i].artist),
          onTap: () => onSelect(i),
        ),
      ),
    );
  }
}
