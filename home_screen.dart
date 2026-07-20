import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../services/playback_service.dart';
import '../services/video_scanner_service.dart';
import '../theme/season_gradients.dart';
import '../theme/theme_service.dart';
import '../widgets/continue_watching_fab.dart';
import '../widgets/video_grid_tile.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VideoScannerService _scanner = VideoScannerService();
  final PlaybackService _playback = PlaybackService();

  bool _loading = true;
  bool _permissionDenied = false;
  List<VideoItem> _videos = [];
  VideoItem? _resumeVideo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    final granted = await _scanner.requestPermission();
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    final videos = await _scanner.scanVideos();
    final lastPath = await _playback.getLastVideoPath();
    VideoItem? resume;
    if (lastPath != null) {
      for (final v in videos) {
        final p = await v.resolvePath();
        if (p == lastPath) {
          resume = v;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _videos = videos;
      _resumeVideo = resume;
      _permissionDenied = false;
      _loading = false;
    });
  }

  Future<void> _openPlayer(VideoItem video) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(video: video, playlist: _videos),
      ),
    );
    _init();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isGradient = themeService.mode == AppThemeMode.gradient;
    final gradient = isGradient
        ? SeasonGradients.gradientFor(themeService.activeSeason)
        : null;

    return Scaffold(
      extendBodyBehindAppBar: isGradient,
      appBar: AppBar(
        title: const Text('My Videos'),
        backgroundColor: isGradient ? Colors.transparent : null,
        elevation: isGradient ? 0 : null,
        actions: [
          PopupMenuButton<AppThemeMode>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Theme',
            onSelected: themeService.setMode,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppThemeMode.system,
                child: Text('System'),
              ),
              PopupMenuItem(value: AppThemeMode.light, child: Text('Light')),
              PopupMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
              PopupMenuItem(
                value: AppThemeMode.gradient,
                child: Text('Season gradient'),
              ),
            ],
          ),
          if (isGradient)
            PopupMenuButton<SeasonOverride>(
              icon: const Icon(Icons.eco_outlined),
              tooltip: 'Season',
              onSelected: themeService.setSeasonOverride,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: SeasonOverride.auto,
                  child: Text('Auto-detect'),
                ),
                PopupMenuItem(
                  value: SeasonOverride.spring,
                  child: Text('Spring'),
                ),
                PopupMenuItem(
                  value: SeasonOverride.summer,
                  child: Text('Summer'),
                ),
                PopupMenuItem(
                  value: SeasonOverride.autumn,
                  child: Text('Autumn'),
                ),
                PopupMenuItem(
                  value: SeasonOverride.winter,
                  child: Text('Winter'),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: gradient != null
            ? BoxDecoration(gradient: gradient)
            : null,
        child: SafeArea(child: _body()),
      ),
      floatingActionButton: _resumeVideo != null
          ? ContinueWatchingFab(onTap: () => _openPlayer(_resumeVideo!))
          : null,
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return _PermissionDeniedView(onRetry: _init);
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos found on this device.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final v = _videos[index];
        return VideoGridTile(video: v, onTap: () => _openPlayer(v));
      },
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;

  const _PermissionDeniedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Storage access is needed to find videos on your phone and memory card.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Grant access'),
            ),
          ],
        ),
      ),
    );
  }
}
