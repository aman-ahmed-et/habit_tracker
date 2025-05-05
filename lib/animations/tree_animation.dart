import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class TreeAnimation extends StatefulWidget {
  final int stage;
  const TreeAnimation({super.key, required this.stage});

  @override
  TreeAnimationState createState() => TreeAnimationState();
}

class TreeAnimationState extends State<TreeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _lastProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _lastProgress = _mapStageToProgress(widget.stage);
  }

  @override
  void didUpdateWidget(TreeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) {
      final newProgress = _mapStageToProgress(widget.stage);
      _controller.animateTo(
        newProgress,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
      _lastProgress = newProgress;
    }
  }

  double _mapStageToProgress(int stage) {
    switch (stage) {
      case 0: return 0.0;
      case 1: return 20 / 75;
      case 2: return 40 / 75;
      case 3: 
      default: return 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Lottie.asset(
        'assets/lottie/tree_grow.json',
        controller: _controller,
        onLoaded: (composition) {
          _controller
            ..duration = composition.duration
            ..value = _lastProgress;
        },
        fit: BoxFit.contain,
      )
    );
  }
}