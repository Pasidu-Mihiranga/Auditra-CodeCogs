import 'dart:async';
import 'package:flutter/material.dart';

class HeroSlideshow extends StatefulWidget {
  final List<String> images;
  final Duration interval;
  final Duration fadeDuration;

  const HeroSlideshow({
    super.key,
    required this.images,
    this.interval = const Duration(seconds: 5),
    this.fadeDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<HeroSlideshow> createState() => _HeroSlideshowState();
}

class _HeroSlideshowState extends State<HeroSlideshow> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _nextIndex = 1;
  Timer? _timer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _zoomControllerA;
  late Animation<double> _zoomAnimationA;
  late AnimationController _zoomControllerB;
  late Animation<double> _zoomAnimationB;

  bool _showingA = true;

  @override
  void initState() {
    super.initState();

    final totalDuration = widget.interval + widget.fadeDuration;

    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _zoomControllerA = AnimationController(
      vsync: this,
      duration: totalDuration,
    );
    _zoomAnimationA = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _zoomControllerA, curve: Curves.easeOut),
    );

    _zoomControllerB = AnimationController(
      vsync: this,
      duration: totalDuration,
    );
    _zoomAnimationB = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _zoomControllerB, curve: Curves.easeOut),
    );

    _zoomControllerA.forward();

    _timer = Timer.periodic(widget.interval, (_) => _advanceSlide());
  }

  void _advanceSlide() {
    if (!mounted) return;

    final nextIdx = (_currentIndex + 1) % widget.images.length;

    setState(() {
      _nextIndex = nextIdx;
    });

    if (_showingA) {
      _zoomControllerB.reset();
      _zoomControllerB.forward();
    } else {
      _zoomControllerA.reset();
      _zoomControllerA.forward();
    }

    _fadeController.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = nextIdx;
        _showingA = !_showingA;
      });
      _fadeController.reset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _zoomControllerA.dispose();
    _zoomControllerB.dispose();
    super.dispose();
  }

  Widget _buildImageLayer(String asset, Animation<double> zoomAnim) {
    return AnimatedBuilder(
      animation: zoomAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: zoomAnim.value,
          child: child,
        );
      },
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomAsset = _showingA ? widget.images[_currentIndex] : widget.images[_nextIndex];
    final topAsset = _showingA ? widget.images[_nextIndex] : widget.images[_currentIndex];
    final bottomZoom = _showingA ? _zoomAnimationA : _zoomAnimationB;
    final topZoom = _showingA ? _zoomAnimationB : _zoomAnimationA;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageLayer(bottomAsset, bottomZoom),
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildImageLayer(topAsset, topZoom),
          ),
        ],
      ),
    );
  }
}
