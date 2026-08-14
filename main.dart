import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.vish0420.audio.channel',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(const AudioOnlyApp());
}

enum Season { spring, summer, autumn, winter }

class SeasonPalette {
  final List<Color> gradient;
  final Color accent;
  const SeasonPalette(this.gradient, this.accent);
}

SeasonPalette paletteFor(Season season) {
  switch (season) {
    case Season.spring:
      return const SeasonPalette([Color(0xFF31572C), Color(0xFF90A955)], Color(0xFFDDEBA0));
    case Season.summer:
      return const SeasonPalette([Color(0xFF0077B6), Color(0xFF48CAE4)], Color(0xFFCAF0F8));
    case Season.autumn:
      return const SeasonPalette([Color(0xFF7F2F1B), Color(0xFFD97706)], Color(0xFFFDBA74));
    case Season.winter:
      return const SeasonPalette([Color(0xFF16324F), Color(0xFF3A506B)], Color(0xFFA6DCEF));
  }
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
  Season season = Season.spring;
  Timer? sleepTimer;
  int currentIndex = -1;

  AudioController() {
    player.currentIndexStream.listen((index) {
      if (index != null) {
        currentIndex = index;
        notifyListeners();
      }
    });
  }

  SeasonPalette get palette => paletteFor(season);
  AudioTrack? get current => currentIndex >= 0 && currentIndex < tracks.length ? tracks[currentIndex] : null;

  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  Future<void> scan() async {
    tracks.clear();
    final paths = await PhotoManager.getAssetPathList(type: RequestType.audio, onlyAll: true);
    if (paths.isEmpty) {
      notifyListeners();
      return;
    }
    final album = paths.first;
    final count = await album.assetCountAsync;
    if (count == 0) {
      notifyListeners();
      return;
    }
    final assets = await album.getAssetListPaged(page: 0, size: count);
    assets.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
    for (final asset in assets) {
      final title = asset.title?.trim().isNotEmpty == true ? asset.title!.trim() : 'Untitled audio';
      tracks.add(AudioTrack(asset: asset, title: title, duration: Duration(seconds: asset.duration)));
    }
    notifyListeners();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= tracks.length) return;
    final sources = <AudioSource>[];
    for (final t in tracks) {
      final path = await t.path();
      if (path == null) continue;
      sources.add(AudioSource.file(path, tag: MediaItem(id: path, title: t.title)));
    }
    if (sources.isEmpty) return;
    await player.setAudioSources(sources, initialIndex: index, initialPosition: Duration.zero);
    await player.play();
    notifyListeners();
  }

  Future<void> pauseOrPlay() async => player.playing ? player.pause() : player.play();
  Future<void> next() async => player.seekToNext();
  Future<void> previous() async => player.seekToPrevious();

  Future<void> seekRelative(int seconds) async {
    final position = player.position + Duration(seconds: seconds);
    final duration = player.duration ?? Duration.zero;
    final clamped = position < Duration.zero ? Duration.zero : (position > duration ? duration : position);
    await player.seek(clamped);
  }

  void setSleep(Duration? duration) {
    sleepTimer?.cancel();
    if (duration == null) return;
    sleepTimer = Timer(duration, () async {
      await player.pause();
      sleepTimer = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    sleepTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}

class AudioOnlyApp extends StatefulWidget {
  const AudioOnlyApp({super.key});
  @override
  State<AudioOnlyApp> createState() => _AudioOnlyAppState();
}

class _AudioOnlyAppState extends State<AudioOnlyApp> {
  late final AudioController controller;
  bool loading = true;
  bool denied = false;

  @override
  void initState() {
    super.initState();
    controller = AudioController();
    _startup();
  }

  Future<void> _startup() async {
    setState(() => loading = true);
    final granted = await controller.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        denied = true;
        loading = false;
      });
      return;
    }
    await controller.scan();
    if (!mounted) return;
    setState(() {
      denied = false;
      loading = false;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final p = controller.palette;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Audio Player',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: p.gradient.last,
            colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: Brightness.dark),
          ),
          home: AudioHomePage(controller: controller, loading: loading, denied: denied, onRefresh: _startup),
        );
      },
    );
  }
}

class AudioHomePage extends StatelessWidget {
  final AudioController controller;
  final bool loading;
  final bool denied;
  final VoidCallback onRefresh;
  const AudioHomePage({super.key, required this.controller, required this.loading, required this.denied, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = controller.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.gradient)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('Audio Player', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
                    PopupMenuButton<Season>(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      onSelected: (s) => controller.season = s,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: Season.spring, child: Text('Spring')),
                        PopupMenuItem(value: Season.summer, child: Text('Summer')),
                        PopupMenuItem(value: Season.autumn, child: Text('Autumn')),
                        PopupMenuItem(value: Season.winter, child: Text('Winter')),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : denied
                        ? _PermissionView(onRefresh: onRefresh)
                        : controller.tracks.isEmpty
                            ? const Center(child: Text('No audio files found.'))
                            : _TrackList(controller: controller),
              ),
              if (!loading && !denied && controller.tracks.isNotEmpty) _MiniPlayer(controller: controller),
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      itemCount: controller.tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_format(track.duration)),
            trailing: IconButton(
              icon: Icon(controller.currentIndex == index && controller.player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
              iconSize: 34,
              onPressed: () => controller.currentIndex == index ? controller.pauseOrPlay() : controller.playAt(index),
            ),
            onTap: () => controller.playAt(index),
          ),
        );
      },
    );
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _MiniPlayer extends StatelessWidget {
  final AudioController controller;
  const _MiniPlayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final current = controller.current;
    if (current == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Colors.black.withOpacity(0.25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: controller.player.positionStream,
              builder: (_, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final max = (controller.player.duration ?? current.duration).inMilliseconds.toDouble();
                final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                return Slider(
                  value: max <= 0 ? 0 : value,
                  min: 0,
                  max: max <= 0 ? 1 : max,
                  onChanged: (v) => controller.player.seek(Duration(milliseconds: v.round())),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(onPressed: controller.previous, icon: const Icon(Icons.skip_previous_rounded)),
                  StreamBuilder<bool>(
                    stream: controller.player.playingStream,
                    builder: (_, snapshot) => IconButton(onPressed: controller.pauseOrPlay, icon: Icon((snapshot.data ?? false) ? Icons.pause_circle_filled : Icons.play_circle_fill), iconSize: 38),
                  ),
                  IconButton(onPressed: controller.next, icon: const Icon(Icons.skip_next_rounded)),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.bedtime_outlined),
                    onSelected: (minutes) => controller.setSleep(Duration(minutes: minutes)),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 15, child: Text('Sleep 15 min')),
                      PopupMenuItem(value: 30, child: Text('Sleep 30 min')),
                      PopupMenuItem(value: 45, child: Text('Sleep 45 min')),
                      PopupMenuItem(value: 60, child: Text('Sleep 60 min')),
                      PopupMenuItem(value: 90, child: Text('Sleep 90 min')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
