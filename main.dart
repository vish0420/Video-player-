import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:photo_manager/photo_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.vish0420.audio_player.channel',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationChannelDescription: 'Background audio controls',
    androidNotificationOngoing: true,
    androidResumeOnClick: true,
    fastForwardInterval: const Duration(seconds: 10),
    rewindInterval: const Duration(seconds: 10),
  );
  runApp(const AudioOnlyApp());
}

enum Season { spring, summer, autumn, winter }

class AudioTrack {
  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  const AudioTrack({required this.id, required this.path, required this.title, required this.artist, required this.album, required this.duration});
  String get extension {
    final name = path.split(Platform.pathSeparator).last;
    final i = name.lastIndexOf('.');
    return i == -1 ? '' : name.substring(i + 1).toUpperCase();
  }
}

class SeasonPalette {
  final List<Color> gradient;
  final Color accent;
  const SeasonPalette(this.gradient, this.accent);
  static SeasonPalette of(Season season) {
    switch (season) {
      case Season.spring: return const SeasonPalette([Color(0xFF163A2F), Color(0xFF0B1714)], Color(0xFF70D6A3));
      case Season.summer: return const SeasonPalette([Color(0xFF513300), Color(0xFF17100A)], Color(0xFFFFB74D));
      case Season.autumn: return const SeasonPalette([Color(0xFF421915), Color(0xFF180D0A)], Color(0xFFFF7043));
      case Season.winter: return const SeasonPalette([Color(0xFF123B55), Color(0xFF07121B)], Color(0xFF66D9FF));
    }
  }
}

class AudioController extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final List<AudioTrack> tracks = [];
  int currentIndex = -1;
  Season _season = Season.spring;
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  AudioController() {
    _indexSub = player.currentIndexStream.listen((index) { currentIndex = index ?? -1; notifyListeners(); });
    _stateSub = player.playerStateStream.listen((_) => notifyListeners());
    _durationSub = player.durationStream.listen((_) => notifyListeners());
  }

  Season get season => _season;
  set season(Season value) { _season = value; notifyListeners(); }
  AudioTrack? get current => currentIndex >= 0 && currentIndex < tracks.length ? tracks[currentIndex] : null;
  bool get isPlaying => player.playing;
  Duration get position => player.position;
  Duration get duration => player.duration ?? current?.duration ?? Duration.zero;
  Duration? get sleepRemaining => _sleepRemaining;
  SeasonPalette get palette => SeasonPalette.of(season);

  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.hasAccess;
  }

  Future<void> scan() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.audio, onlyAll: true, hasAll: true);
    final found = <AudioTrack>[];
    if (paths.isNotEmpty) {
      final all = paths.first;
      final count = await all.assetCountAsync;
      if (count > 0) {
        final assets = await all.getAssetListPaged(page: 0, size: count);
        for (final asset in assets) {
          final file = await asset.file;
          if (file == null) continue;
          final rawTitle = asset.title?.trim();
          final title = (rawTitle == null || rawTitle.isEmpty)
              ? file.path.split(Platform.pathSeparator).last.replaceFirst(RegExp(r'\.[^.]+$'), '')
              : rawTitle;
          found.add(AudioTrack(
            id: asset.id,
            path: file.path,
            title: title,
            artist: 'Unknown artist',
            album: 'Unknown album',
            duration: Duration(seconds: asset.duration),
          ));
        }
      }
    }
    found.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final previousPath = current?.path;
    tracks..clear()..addAll(found);
    if (tracks.isEmpty) {
      await player.stop();
      currentIndex = -1;
    } else {
      final keepIndex = previousPath == null ? 0 : tracks.indexWhere((e) => e.path == previousPath);
      await _loadQueue(startIndex: keepIndex >= 0 ? keepIndex : 0, autoPlay: false);
    }
    notifyListeners();
  }

  Future<void> _loadQueue({required int startIndex, required bool autoPlay}) async {
    if (tracks.isEmpty) return;
    final sources = tracks.map((track) => AudioSource.file(track.path, tag: MediaItem(id: track.id, title: track.title, artist: track.artist, album: track.album, duration: track.duration))).toList();
    await player.setAudioSource(ConcatenatingAudioSource(children: sources), initialIndex: startIndex.clamp(0, tracks.length - 1), initialPosition: Duration.zero);
    currentIndex = player.currentIndex ?? startIndex;
    if (autoPlay) await player.play();
    notifyListeners();
  }

  Future<void> playTrack(int index) async {
    if (index < 0 || index >= tracks.length) return;
    if (currentIndex != index || player.audioSource == null) {
      await _loadQueue(startIndex: index, autoPlay: true);
    } else {
      await player.play();
    }
  }

  Future<void> togglePlay() async {
    if (tracks.isEmpty) return;
    if (player.playing) {
      await player.pause();
    } else if (currentIndex >= 0) {
      await player.play();
    } else {
      await playTrack(0);
    }
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
    } else if (tracks.isNotEmpty) {
      await player.seek(Duration.zero, index: 0);
    }
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  void swipe(double velocity) {
    if (velocity < -60) { unawaited(next()); }
    if (velocity > 60) { unawaited(previous()); }
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepRemaining = duration;
    if (duration != null) {
      final end = DateTime.now().add(duration);
      _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final remaining = end.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          timer.cancel();
          _sleepRemaining = null;
          await player.pause();
        } else {
          _sleepRemaining = remaining;
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    unawaited(_indexSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(player.dispose());
    super.dispose();
  }
}

class AudioOnlyApp extends StatefulWidget {
  const AudioOnlyApp({super.key});
  @override State<AudioOnlyApp> createState() => _AudioOnlyAppState();
}

class _AudioOnlyAppState extends State<AudioOnlyApp> {
  late final AudioController controller;
  bool loading = true;
  bool denied = false;

  @override
  void initState() {
    super.initState();
    controller = AudioController()..addListener(_onChange);
    _startup();
  }

  void _onChange() { if (mounted) setState(() {}); }

  Future<void> _startup() async {
    setState(() { loading = true; denied = false; });
    try {
      final ok = await controller.requestPermission();
      if (!ok) { setState(() { denied = true; loading = false; }); return; }
      await controller.scan();
      if (mounted) setState(() { loading = false; });
    } catch (_) {
      if (mounted) setState(() { loading = false; });
    }
  }

  @override
  void dispose() { controller.removeListener(_onChange); controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = controller.palette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio Player',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: p.gradient.last, colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: Brightness.dark)),
      home: AudioHomePage(controller: controller, loading: loading, denied: denied, onRefresh: _startup),
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
        child: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
            child: Row(children: [
              const Expanded(child: Text('Audio Player', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700))),
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
              PopupMenuButton<Season>(icon: const Icon(Icons.auto_awesome_rounded), onSelected: (s) => controller.season = s, itemBuilder: (_) => const [
                PopupMenuItem(value: Season.spring, child: Text('Spring')),
                PopupMenuItem(value: Season.summer, child: Text('Summer')),
                PopupMenuItem(value: Season.autumn, child: Text('Autumn')),
                PopupMenuItem(value: Season.winter, child: Text('Winter')),
              ]),
            ]),
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
        ])),
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _PermissionView({required this.onRefresh});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.music_off_rounded, size: 64),
    const SizedBox(height: 14),
    const Text('Allow audio access to show your music library.', textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton(onPressed: onRefresh, child: const Text('Grant audio access')),
  ]));
}

class _TrackList extends StatelessWidget {
  final AudioController controller;
  const _TrackList({required this.controller});
  @override
  Widget build(BuildContext context) {
    final p = controller.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: controller.tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, i) {
        final t = controller.tracks[i];
        final active = controller.currentIndex == i;
        return Material(color: active ? p.accent.withValues(alpha: .13) : Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(18), child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: CircleAvatar(backgroundColor: p.accent.withValues(alpha: .18), child: Icon(Icons.music_note_rounded, color: p.accent)),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${t.artist}  •  ${t.extension}', maxLines: 1),
          trailing: active && controller.isPlaying ? const Icon(Icons.equalizer_rounded) : const Icon(Icons.play_arrow_rounded),
          onTap: () => controller.playTrack(i),
        ));
      },
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final AudioController controller;
  const _MiniPlayer({required this.controller});

  String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _sleep(BuildContext context) async {
    final picked = await showModalBottomSheet<Duration?>(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Sleep timer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      for (final m in [15, 30, 45, 60, 90]) ListTile(title: Text('$m minutes'), onTap: () => Navigator.pop(context, Duration(minutes: m))),
      ListTile(title: const Text('Off'), onTap: () => Navigator.pop(context, null)),
    ])));
    controller.setSleepTimer(picked);
  }

  @override
  Widget build(BuildContext context) {
    final track = controller.current;
    if (track == null) return const SizedBox.shrink();
    final totalMs = controller.duration.inMilliseconds;
    final total = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final value = controller.position.inMilliseconds.toDouble().clamp(0.0, total).toDouble();
    return GestureDetector(
      onHorizontalDragEnd: (details) => controller.swipe(details.primaryVelocity ?? 0),
      child: Material(color: Colors.black.withValues(alpha: .22), elevation: 14, child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Expanded(child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), IconButton(onPressed: () => _sleep(context), icon: const Icon(Icons.bedtime_outlined))]),
        Slider(value: value, max: total, activeColor: controller.palette.accent, onChanged: (v) => controller.seek(Duration(milliseconds: v.round()))),
        Row(children: [
          Text(_clock(controller.position), style: const TextStyle(fontSize: 12)),
          const Spacer(),
          IconButton(onPressed: controller.previous, icon: const Icon(Icons.skip_previous_rounded, size: 30)),
          IconButton(onPressed: controller.togglePlay, iconSize: 52, icon: Icon(controller.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded)),
          IconButton(onPressed: controller.next, icon: const Icon(Icons.skip_next_rounded, size: 30)),
          const Spacer(),
          Text(_clock(controller.duration), style: const TextStyle(fontSize: 12)),
        ]),
        if (controller.sleepRemaining != null) Text('Sleep: ${_clock(controller.sleepRemaining!)}', style: TextStyle(color: controller.palette.accent, fontWeight: FontWeight.w600)),
      ]))),
    );
  }
}
