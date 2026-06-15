import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/sync_engine.dart';
import 'services/theme_service.dart';
import 'services/error_reporter.dart';
import 'services/realtime_service.dart';
import 'services/push_service.dart';
import 'theme/app_colors.dart';

void main() async {
  // IMPORTANT: Initialize bindings in the ROOT zone to avoid the
  // "Zone mismatch" error on Flutter Web.
  WidgetsFlutterBinding.ensureInitialized();

  // Hive initialisation
  await Hive.initFlutter();
  await SyncEngine.init();

  // Global error handler
  FlutterError.onError = (details) {
    ErrorReporter.reportFlutterError(details);
  };

  // HttpOverrides is only available on dart:io platforms (not web).
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }

  final themeService = ThemeService();

  runZonedGuarded(() {
    runApp(
      ChangeNotifierProvider.value(
        value: themeService,
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    ErrorReporter.reportError(error, stack);
  });
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    return MaterialApp(
      title: 'Auditra',
      debugShowCheckedModeBanner: false,
      theme: AppColors.lightTheme,
      darkTheme: AppColors.darkTheme,
      themeMode: themeService.mode,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _ambientController;
  
  // Staggered reveal animations
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();
    
    // Entry animation controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    
    // Background breathing/floating controller
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    
    // Setup staggered reveals
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    // Start animation and then check auth
    _entryController.forward().then((_) {
      _checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Wait a little bit extra to let user appreciate the entry animation
    await Future.delayed(const Duration(milliseconds: 600));
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      // Feature #3 (C1): initialise push + real-time channels once logged in.
      try {
        await PushService.init();
      } catch (_) {}
      try {
        await RealTimeService.instance.connect('/ws/notifications/');
        RealTimeService.instance.addHandler((msg) {
          final title = (msg['title'] ?? msg['type'] ?? 'Notification').toString();
          final body = (msg['message'] ?? msg['body'] ?? '').toString();
          PushService.showNotification(
            title: title,
            body: body,
            payload: msg['action_url']?.toString(),
          );
        });
      } catch (_) {}

      final roleResult = await ApiService.getMyRole();
      if (!mounted) return;

      // If both access and refresh tokens are expired, force re-login
      if (roleResult['success'] == false) {
        final msg = roleResult['message'] ?? '';
        final isAuthError = msg.contains('expired') ||
            msg.contains('login') ||
            msg.contains('authenticated') ||
            msg.contains('Session');
        if (isAuthError) {
          await ApiService.logout();
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
          return;
        }
      }

      final role = await ApiService.getUserRole();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(userRole: role ?? 'unassigned'),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Midnight Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF070B19), // Deep midnight blue
                    Color(0xFF0F172A), // Slate dark
                    Color(0xFF1E3A8A), // Rich royal navy
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // 2. Blurred Slideshow Background overlay
          const Positioned.fill(
            child: _SplashSlideshow(
              images: [
                'assets/hero1.webp',
                'assets/hero2.webp',
                'assets/hero3.webp',
              ],
            ),
          ),
          
          // 3. Floating Ambient Glowing Blobs
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) {
              return Stack(
                children: [
                  AmbientBlob(
                    progress: _ambientController.value,
                    begin: const Alignment(-0.8, -0.6),
                    end: const Alignment(-0.3, -0.2),
                    size: 260,
                    color: AppColors.accent,
                  ),
                  AmbientBlob(
                    progress: 1.0 - _ambientController.value,
                    begin: const Alignment(0.8, 0.6),
                    end: const Alignment(0.4, 0.2),
                    size: 300,
                    color: Colors.indigo.shade700,
                  ),
                ],
              );
            },
          ),
          
          // 4. Centered Logo and Taglines
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with Hero tag for smooth flying transition to login screen
                Hero(
                  tag: 'app_logo',
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/Company Logo White.png',
                        width: 170,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.shield_outlined,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // App Title
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: const Text(
                      'Auditra',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Text(
                      'Securing What Matters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 2.5,
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 5. Shimmer Line Loader at bottom
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 60.0),
              child: ShimmerLineLoader(),
            ),
          ),
        ],
      ),
    );
  }
}

class AmbientBlob extends StatelessWidget {
  final double progress;
  final Alignment begin;
  final Alignment end;
  final double size;
  final Color color;

  const AmbientBlob({
    super.key,
    required this.progress,
    required this.begin,
    required this.end,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment.lerp(begin, end, progress)!;
    final opacity = (progress * 0.12) + 0.05; // Oscillates between 0.05 and 0.17

    return Align(
      alignment: alignment,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: size * 0.45,
                spreadRadius: size * 0.08,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerLineLoader extends StatefulWidget {
  const ShimmerLineLoader({super.key});

  @override
  State<ShimmerLineLoader> createState() => _ShimmerLineLoaderState();
}

class _ShimmerLineLoaderState extends State<ShimmerLineLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _animation = Tween<double>(begin: -1.2, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(1.5),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: FractionalTranslation(
              translation: Offset(_animation.value, 0.0),
              child: Container(
                width: 75,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Smooth crossfading slideshow for the splash screen background.
/// Shows all hero images with blur and low opacity as an ambient background.
class _SplashSlideshow extends StatefulWidget {
  final List<String> images;

  const _SplashSlideshow({required this.images});

  @override
  State<_SplashSlideshow> createState() => _SplashSlideshowState();
}

class _SplashSlideshowState extends State<_SplashSlideshow> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _nextIndex = 1;
  bool _showingA = true;
  Timer? _timer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _zoomControllerA;
  late Animation<double> _zoomAnimA;
  late AnimationController _zoomControllerB;
  late Animation<double> _zoomAnimB;

  static const _interval = Duration(seconds: 4);
  static const _fadeDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    final totalDur = _interval + _fadeDuration;

    _fadeController = AnimationController(vsync: this, duration: _fadeDuration);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _zoomControllerA = AnimationController(vsync: this, duration: totalDur);
    _zoomAnimA = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _zoomControllerA, curve: Curves.easeOut),
    );

    _zoomControllerB = AnimationController(vsync: this, duration: totalDur);
    _zoomAnimB = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _zoomControllerB, curve: Curves.easeOut),
    );

    _zoomControllerA.forward();
    _timer = Timer.periodic(_interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted) return;
    final nextIdx = (_currentIndex + 1) % widget.images.length;
    setState(() => _nextIndex = nextIdx);

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

  Widget _buildLayer(String asset, Animation<double> zoom) {
    return AnimatedBuilder(
      animation: zoom,
      builder: (context, child) => Transform.scale(scale: zoom.value, child: child),
      child: Opacity(
        opacity: 0.14,
        child: Image.asset(asset, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomAsset = _showingA ? widget.images[_currentIndex] : widget.images[_nextIndex];
    final topAsset = _showingA ? widget.images[_nextIndex] : widget.images[_currentIndex];
    final bottomZoom = _showingA ? _zoomAnimA : _zoomAnimB;
    final topZoom = _showingA ? _zoomAnimB : _zoomAnimA;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildLayer(bottomAsset, bottomZoom),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildLayer(topAsset, topZoom),
        ),
        // Blur overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}
