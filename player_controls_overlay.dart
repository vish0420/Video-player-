import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_item.dart';

class PlayerControlsOverlay extends StatefulWidget {
  final Player player;
  final VideoItem video;
  final bool hasNext;
  final bool hasPrevious;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  /// Called whenever the user interacts with a control, so the parent can
  /// reset the auto-hide timer.
  final VoidCallback onInteraction;

  const PlayerControlsOverlay({
    super.key,
    required this.player,
    required this.video,
    required this.hasNext,
    required this.hasPrevious,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.onInteraction,
  });

  @override
  State<PlayerControlsOverlay> createState() => _PlayerControlsOverlayState();
}

class _PlayerControlsOverlayState extends State<PlayerControlsOverlay> {
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showSpeedMenu() {
    widget.onInteraction();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: _speeds
              .map(
                (s) => ListTile(
                  title: Text('${s}x'),
                  onTap: () {
                    widget.player.setRate(s);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showSubtitleMenu() {
    widget.onInteraction();
    final tracks = widget.player.state.tracks.subtitle;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('Off'),
              onTap: () {
                widget.player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(context);
              },
            ),
            ...tracks.map(
              (t) => ListTile(
                title: Text(t.title ?? t.language ?? 'Subtitle track'),
                onTap: () {
                  widget.player.setSubtitleTrack(t);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    widget.onInteraction();
    final file = await widget.video.asset.file;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onInteraction,
      child: Stack(
        children: [
          _topBar(),
          _centerTransport(),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.72), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onClose,
              ),
              Expanded(
                child: Text(
                  widget.video.title,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.speed, color: Colors.white),
                onPressed: _showSpeedMenu,
                tooltip: 'Playback speed',
              ),
              IconButton(
                icon: const Icon(
                  Icons.subtitles_outlined,
                  color: Colors.white,
                ),
                onPressed: _showSubtitleMenu,
                tooltip: 'Subtitles',
              ),
              // Share button, styled as a rocket tilted to the right.
              Transform.rotate(
                angle: 0.35,
                child: IconButton(
                  icon: const Icon(
                    Icons.rocket_launch_outlined,
                    color: Colors.white,
                  ),
                  onPressed: _share,
                  tooltip: 'Share',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerTransport() {
    return Center(
      child: StreamBuilder<bool>(
        stream: widget.player.stream.playing,
        initialData: widget.player.state.playing,
        builder: (context, snapshot) {
          final playing = snapshot.data ?? false;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: widget.hasPrevious
                    ? () {
                        widget.onInteraction();
                        widget.onPrevious();
                      }
                    : null,
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 58,
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.white,
                ),
                onPressed: () {
                  widget.onInteraction();
                  playing ? widget.player.pause() : widget.player.play();
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: widget.hasNext
                    ? () {
                        widget.onInteraction();
                        widget.onNext();
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.72), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: StreamBuilder<Duration>(
            stream: widget.player.stream.duration,
            initialData: widget.player.state.duration,
            builder: (context, durSnapshot) {
              final dur = durSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: widget.player.stream.position,
                initialData: widget.player.state.position,
                builder: (context, posSnapshot) {
                  final pos = posSnapshot.data ?? Duration.zero;
                  final maxMs = dur.inMilliseconds > 0
                      ? dur.inMilliseconds.toDouble()
                      : 1.0;
                  final value = pos.inMilliseconds
                      .clamp(0, maxMs.toInt())
                      .toDouble();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: maxMs,
                          onChangeStart: (_) => widget.onInteraction(),
                          onChanged: (v) {
                            widget.player.seek(
                              Duration(milliseconds: v.toInt()),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(pos),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(dur),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
