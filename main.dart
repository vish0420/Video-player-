import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:photo_manager/photo_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.vish0420.audio.channel',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (_) {}
  runApp(const AudioPlayerApp());
}

class AudioTrack {
  final AssetEntity asset;
  final String title;
  final Duration duration;

  const AudioTrack({required this.asset, required this.title, required this.duration});

  Future<String?> path() async => (await asset.file)?.path;
}

class AudioController extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final List<AudioTrack> tracks = [];
  int currentIndex = -1;
  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;

  AudioTrack? get current => currentIndex >= 0 && currentIndex < tracks.length ? tracks[currentIndex] : null;

  Duration? get sleepRemaining {
    final end = _sleepEndsAt;
    if (end == null) return null;
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  Future<void> scan() async {
    tracks.clear();
    currentIndex = -1;
    notifyListeners();

    // Only RequestType.audio is queried, so images and videos never enter the list.
    final paths = await PhotoManager.getAssetPathList(type: RequestType.audio, onlyAll: true);
    if (paths.isEmpty) return;
    final album = paths.first;
    final count = await album.assetCountAsync;
    if (count == 0) return;

    final assets = await album.getAssetListPaged(page: 0, size: count);
    assets.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
    for (final asset in assets) {
      final title = asset.title?.trim();
      tracks.add(AudioTrack(
        asset: asset,
        title: title?.isNotEmpty == true ? title! : 'Untitled audio',
        duration: Duration(seconds: asset.duration),
      ));
    }
    notifyListeners();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= tracks.length) return;
    final track = tracks[index];
    final path = await track.path();
    if (path == null) return;

    try {
      currentIndex = index;
      notifyListeners();
      // Resolve/load only the selected file to reduce memory pressure.
      await player.setAudioSource(AudioSource.file(
        path,
        tag: MediaItem(
          id: path,
          title: track.title,
          album: 'Audio Player',
          duration: track.duration,
        ),
      ));
      await player.play();
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await player.pause();
    } else if (current != null) {
      await player.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (tracks.isEmpty) return;
    await playAt(currentIndex < tracks.length - 1 ? currentIndex + 1 : 0);
  }

  Future<void> previous() async {
    if (tracks.isEmpty) return;
    await playAt(currentIndex > 0 ? currentIndex - 1 : tracks.length - 1);
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    if (duration != null) {
      _sleepEndsAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () async {
        await player.pause();
        _sleepTimer = null;
        _sleepEndsAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}

class AudioPlayerApp extends StatefulWidget {
  const AudioPlayerApp({super.key});
  @override
  State<AudioPlayerApp> createState() => _AudioPlayerAppState();
}

class _AudioPlayerAppState extends State<AudioPlayerApp> {
  late final AudioController controller;
  bool loading = true;
  bool permissionDenied = false;

  @override
  void initState() {
    super.initState();
    controller = AudioController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      permissionDenied = false;
    });
    try {
      final granted = await controller.requestPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          loading = false;
          permissionDenied = true;
        });
        return;
      }
      await controller.scan();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio Player',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: AudioHomePage(
        controller: controller,
        loading: loading,
        permissionDenied: permissionDenied,
        onRefresh: _loadLibrary,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class AudioHomePage extends StatelessWidget {
  final AudioController controller;
  final bool loading;
  final bool permissionDenied;
  final VoidCallback onRefresh;

  const AudioHomePage({
    super.key,
    required this.controller,
    required this.loading,
    required this.permissionDenied,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Audio Player'),
          actions: [
            IconButton(
              tooltip: 'Sleep timer',
              icon: const Icon(Icons.bedtime_outlined),
              onPressed: () => _showSleepTimer(context),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : permissionDenied
                ? _PermissionView(onRefresh: onRefresh)
                : controller.tracks.isEmpty
                    ? const Center(child: Text('No audio files found.'))
                    : Column(
                        children: [
                          Expanded(child: _TrackList(controller: controller)),
                          if (controller.current != null) _MiniPlayer(controller: controller),
                        ],
                      ),
      ),
    );
  }

  Future<void> _showSleepTimer(BuildContext context) async {
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.bedtime_outlined),
              title: Text('Sleep timer'),
              subtitle: Text('Pause playback automatically'),
            ),
            for (final minutes in [15, 30, 45, 60, 90, 120])
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () => Navigator.pop(sheetContext, Duration(minutes: minutes)),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Turn off'),
              onTap: () => Navigator.pop(sheetContext, Duration.zero),
            ),
          ],
        ),
      ),
    );
    if (choice != null) controller.setSleepTimer(choice == Duration.zero ? null : choice);
  }
}

class _PermissionView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _PermissionView({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off_rounded, size: 64),
              const SizedBox(height: 14),
              const Text('Allow audio access to show your music library.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRefresh, child: const Text('Grant audio access')),
            ],
          ),
        ),
      );
}

class _TrackList extends StatelessWidget {
  final AudioController controller;
  const _TrackList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: controller.tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        final active = controller.currentIndex == index;
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          selected: active,
          leading: const CircleAvatar(child: Icon(Icons.music_note_rounded)),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_formatDuration(track.duration)),
          trailing: Icon(active && controller.player.playing ? Icons.equalizer_rounded : Icons.play_arrow_rounded),
          onTap: () => controller.playAt(index),
        );
      },
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final AudioController controller;
  const _MiniPlayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final current = controller.current;
    if (current == null) return const SizedBox.shrink();
    final remaining = controller.sleepRemaining;
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: controller.previous, icon: const Icon(Icons.skip_previous_rounded)),
                  StreamBuilder<PlayerState>(
                    stream: controller.player.playerStateStream,
                    builder: (_, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        iconSize: 34,
                        onPressed: controller.togglePlayPause,
                        icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                      );
                    },
                  ),
                  IconButton(onPressed: controller.next, icon: const Icon(Icons.skip_next_rounded)),
                ],
              ),
              if (remaining != null) Text('Sleep timer: ${_formatDuration(remaining)}'),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
