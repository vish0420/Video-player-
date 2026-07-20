import 'package:flutter/material.dart';

/// The round button in the bottom-right corner that resumes the most
/// recently played video from where it was stopped.
class ContinueWatchingFab extends StatelessWidget {
  final VoidCallback onTap;

  const ContinueWatchingFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      shape: const CircleBorder(),
      tooltip: 'Resume last video',
      child: const Icon(Icons.play_arrow_rounded, size: 30),
    );
  }
}
