import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/video_item.dart';
import '../services/playback_service.dart';
import '../widgets/gesture_control_layer.dart';
import '../widgets/player_controls_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final VideoItem video;
  final List<VideoItem> playlist;

  const PlayerScreen({
    super.key,
    required this.video,
    required this.playlist,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final PlaybackService _playback = PlaybackService();

  int _currentIndex = 0;
  String? _currentPath;

  double _overlayBrightness = 1.0; // 1.0 = no dimming overlay
  double _zoom = 1.0;
  bool _controlsVisible = true;

  Timer? _hideTimer;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    final foundIndex = widget.playlist.indexWhere(
      (v) => v.asset.id == widget.video.asset.id,
    );
    _currentIndex = foundIndex >= 0 ? foundIndex : 0;

    _loadCurrent(resume: true);

    _positionSub = _player.stream.position.listen((pos) {
      // Periodically checkpoint progress so a crash/kill doesn't lose it.
      if (_currentPath != null && pos.inSeconds % 5 == 0) {
        _playback.saveLastPlayed(_currentPath!, pos);
      }
    });

    _resetHideTimer();
  }

  Future<void> _loadCurrent({bool resume = false}) async {
    final video = widget.playlist[_currentIndex];
    final path = await video.resolvePath();
    if (path == null || !mounted) return;

    _currentPath = path;
    await _player.open(Media(path));

    if (resume) {
      final savedPos = await _playback.getPosition(path);
      if (savedPos > Duration.zero) {
        await _player.seek(savedPos);
      }
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _resetHideTimer();
  }

  void _playNext() {
    if (_currentIndex < widget.playlist.length - 1) {
      setState(() => _currentIndex++);
      _loadCurrent();
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadCurrent();
    }
  }

  void _adjustBrightness(double delta) {
    setState(() {
      _overlayBrightness = (_overlayBrightness + delta).clamp(0.15, 1.0);
    });
  }

  void _adjustVolume(double delta) {
    final current = _player.state.volume;
    final next = (current + delta * 100).clamp(0.0, 100.0);
    _player.setVolume(next);
  }

  void _adjustZoom(double scale) {
    setState(() => _zoom = scale.clamp(1.0, 3.0));
  }

  void _seekRelative(Duration offset) {
    final target = _player.state.position + offset;
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  void _saveProgress() {
    if (_currentPath != null) {
      _playback.saveLastPlayed(_currentPath!, _player.state.position);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionSub?.cancel();
    _saveProgress();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) => _saveProgress(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Transform.scale(
                scale: _zoom,
                child: Video(controller: _controller, controls: NoVideoControls),
              ),
            ),
            GestureControlLayer(
              onTap: _toggleControls,
              onDoubleTapLeft: () =>
                  _seekRelative(const Duration(seconds: -10)),
              onDoubleTapRight: () =>
                  _seekRelative(const Duration(seconds: 10)),
              onVerticalDragLeft: _adjustBrightness,
              onVerticalDragRight: _adjustVolume,
              onScale: _adjustZoom,
            ),
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(1 - _overlayBrightness),
              ),
            ),
            if (_controlsVisible)
              PlayerControlsOverlay(
                player: _player,
                video: widget.playlist[_currentIndex],
                hasNext: _currentIndex < widget.playlist.length - 1,
                hasPrevious: _currentIndex > 0,
                onNext: _playNext,
                onPrevious: _playPrevious,
                onClose: () => Navigator.of(context).pop(),
                onInteraction: _resetHideTimer,
              ),
          ],
        ),
      ),
    );
  }
}
