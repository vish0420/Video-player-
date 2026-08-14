import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'audio_item.dart';
import 'playback_service.dart';

class AudioPlayerScreen extends StatefulWidget {
  final AudioItem audio;
  final List<AudioItem> playlist;

  const AudioPlayerScreen({super.key, required this.audio, required this.playlist});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final Player _player;
  final PlaybackService _playback = PlaybackService();
  int _index = 0;
  String? _path;
  bool _repeat = false;
  bool _shuffle = false;
  StreamSubscription<Duration>? _positionSub;

  AudioItem get current => widget.playlist[_index];

  @override
  void initState() {
    super.initState();
    _player = Player();
    final found = widget.playlist.indexWhere((a) => a.asset.id == widget.audio.asset.id);
    _index = found >= 0 ? found : 0;
    _open(resume: true);
    _positionSub = _player.stream.position.listen((pos) {
      if (_path != null && pos.inSeconds % 5 == 0) {
        _playback.saveLastPlayed(_path!, pos);
      }
    });
  }

  Future<void> _open({bool resume = false}) async {
    final path = await current.resolvePath();
    if (!mounted || path == null) return;
    _path = path;
    await _player.open(Media(path));
    if (resume) {
      final saved = await _playback.getPosition(path);
      if (saved > Duration.zero) await _player.seek(saved);
    }
    await _player.play();
  }

  void _next() {
    if (widget.playlist.isEmpty) return;
    if (_shuffle) {
      _index = (_index + 2) % widget.playlist.length;
    } else if (_index < widget.playlist.length - 1) {
      _index++;
    } else if (_repeat) {
      _index = 0;
    } else {
      return;
    }
    setState(() {});
    _open();
  }

  void _previous() {
    if (_player.state.position.inSeconds > 3) {
      _player.seek(Duration.zero);
      return;
    }
    if (_index > 0) {
      setState(() => _index--);
      _open();
    }
  }

  void _seek(Duration amount) {
    final target = _player.state.position + amount;
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  String _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    if (_path != null) _playback.saveLastPlayed(_path!, _player.state.position);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
        actions: [
          IconButton(icon: Icon(_shuffle ? Icons.shuffle_on : Icons.shuffle), onPressed: () => setState(() => _shuffle = !_shuffle)),
          IconButton(icon: Icon(_repeat ? Icons.repeat_on : Icons.repeat), onPressed: () => setState(() => _repeat = !_repeat)),
        ],
      ),
      body: SafeArea(
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
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF182848), Color(0xFF4B6CB7)]),
                  boxShadow: const [BoxShadow(blurRadius: 30, spreadRadius: 2)],
                ),
                child: const Icon(Icons.music_note_rounded, size: 110, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Text(current.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('${current.artist} • ${current.album}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              StreamBuilder<Duration>(
                stream: _player.stream.duration,
                initialData: _player.state.duration,
                builder: (context, d) => StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  initialData: _player.state.position,
                  builder: (context, p) {
                    final duration = d.data ?? Duration.zero;
                    final position = p.data ?? Duration.zero;
                    final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                    final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                    return Column(children: [
                      Slider(value: value, min: 0, max: max, onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt()))),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_time(position)), Text(_time(duration))]),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: _player.state.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(iconSize: 32, onPressed: _previous, icon: const Icon(Icons.skip_previous_rounded)),
                    IconButton(iconSize: 34, onPressed: () => _seek(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded)),
                    const SizedBox(width: 8),
                    IconButton(iconSize: 72, onPressed: () => playing ? _player.pause() : _player.play(), icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded)),
                    const SizedBox(width: 8),
                    IconButton(iconSize: 34, onPressed: () => _seek(const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded)),
                    IconButton(iconSize: 32, onPressed: _next, icon: const Icon(Icons.skip_next_rounded)),
                  ]);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: () => _player.setRate(_player.state.rate == 1.0 ? 1.5 : 1.0), icon: const Icon(Icons.speed), label: const Text('Playback speed')),
              const Spacer(),
              const Text('Audio output uses your phone\'s native audio path. If Dolby is enabled at the system/device level, compatible processing is retained.'),
            ],
          ),
        ),
      ),
    );
  }
}
