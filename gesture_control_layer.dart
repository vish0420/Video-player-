import 'package:flutter/material.dart';

/// Transparent layer sitting over the video surface that turns touch
/// gestures into player actions, the way most mobile video players work:
///
/// - Single tap: toggle the controls overlay
/// - Double tap left / right half: seek back / forward 10s
/// - One-finger vertical drag on the left half: adjust the on-screen
///   brightness dimmer
/// - One-finger vertical drag on the right half: adjust volume
/// - Two-finger pinch: zoom the video in/out
class GestureControlLayer extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final ValueChanged<double> onVerticalDragLeft;
  final ValueChanged<double> onVerticalDragRight;
  final ValueChanged<double> onScale;

  const GestureControlLayer({
    super.key,
    required this.onTap,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onVerticalDragLeft,
    required this.onVerticalDragRight,
    required this.onScale,
  });

  @override
  State<GestureControlLayer> createState() => _GestureControlLayerState();
}

class _GestureControlLayerState extends State<GestureControlLayer> {
  double _gestureBaseZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onScaleStart: (details) {
        _gestureBaseZoom = 1.0;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          widget.onScale(_gestureBaseZoom * details.scale);
        } else if (details.pointerCount == 1) {
          // Dragging up should increase the value, so invert dy.
          final delta = -details.focalPointDelta.dy / 300;
          if (details.localFocalPoint.dx < width / 2) {
            widget.onVerticalDragLeft(delta);
          } else {
            widget.onVerticalDragRight(delta);
          }
        }
      },
      onDoubleTapDown: (details) {
        if (details.localPosition.dx < width / 2) {
          widget.onDoubleTapLeft();
        } else {
          widget.onDoubleTapRight();
        }
      },
    );
  }
}
