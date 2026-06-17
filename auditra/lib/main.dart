import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/field_officer_dashboard.dart';
import 'widgets/hero_slideshow.dart';
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
  late AnimationController _wavePhaseController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();

    // Main sequence controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Continuous wave rippling controller
    _wavePhaseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Liquid fill sequence: 
    // 10% delay -> 35% rise -> 10% hold -> 35% fall -> 10% delay
    _fillAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.70).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.70, end: 0.70), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.70, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 10),
    ]).animate(_entryController);

    // Start animation and check auth
    _entryController.forward().then((_) {
      _checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _wavePhaseController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      try { await PushService.init(); } catch (_) {}
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

      if (roleResult['success'] == false) {
        final msg = roleResult['message'] ?? '';
        final isAuthError = msg.contains('expired') || msg.contains('login') || msg.contains('authenticated') || msg.contains('Session');
        if (isAuthError) {
          await ApiService.logout();
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, a1, a2) => const LoginScreen(),
              transitionsBuilder: (context, a1, a2, child) => FadeTransition(opacity: a1, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
          return;
        }
      }

      final role = await ApiService.getUserRole();
      if (role == 'field_officer') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FieldOfficerDashboard()),
        );
      } else {
        final roleDisplay = (roleResult['success'] && roleResult['data'] != null)
            ? (roleResult['data']['role_display'] ?? role)
            : role;

        await ApiService.logout();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, a1, a2) => LoginScreen(restrictionRole: roleDisplay ?? 'User'),
            transitionsBuilder: (context, a1, a2, child) => FadeTransition(opacity: a1, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, a1, a2) => const WelcomeScreen(),
          transitionsBuilder: (context, a1, a2, child) => FadeTransition(opacity: a1, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  Widget _buildAnimatedText(double t, bool isDark) {
    if (t < 0.15) {
      double opacity = 1.0;
      if (t > 0.1) opacity = 1.0 - ((t - 0.1) / 0.05); // Fade out logo
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Image.asset(
          'assets/Company Logo White.png',
          width: 220,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.shield, size: 80, color: AppColors.primary),
        ),
      );
    } else if (t < 0.5) {
      double opacity = 1.0;
      if (t < 0.2) opacity = (t - 0.15) / 0.05; // Fade in
      else if (t > 0.45) opacity = 1.0 - ((t - 0.45) / 0.05); // Fade out
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          'Analyzing Records...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    } else if (t < 0.85) {
      double opacity = 1.0;
      if (t < 0.55) opacity = (t - 0.5) / 0.05; // Fade in
      else if (t > 0.8) opacity = 1.0 - ((t - 0.8) / 0.05); // Fade out
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          'Securing Data...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // The animated liquid wave background
          AnimatedBuilder(
            animation: Listenable.merge([_entryController, _wavePhaseController]),
            builder: (context, child) {
              return ClipPath(
                clipper: LiquidSplashClipper(
                  fillLevel: _fillAnimation.value,
                  phase: _wavePhaseController.value * 2 * math.pi,
                ),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0xFF0EA5E9), // Light blue from attendance tab
                        Color(0xFF0284C7), // Dark blue from attendance tab
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // The dynamic text/logo content centered in the top half
          AnimatedBuilder(
            animation: _entryController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.15,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildAnimatedText(_entryController.value, isDark),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class LiquidSplashClipper extends CustomClipper<Path> {
  final double fillLevel;
  final double phase;

  LiquidSplashClipper({required this.fillLevel, required this.phase});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (fillLevel <= 0.0) return path;

    final amplitude = 20.0; // Height of the wave
    final liquidTopY = size.height - (size.height * fillLevel);

    path.moveTo(0, size.height);
    path.lineTo(0, liquidTopY);

    for (double i = 0; i <= size.width; i++) {
      // 1.0 wave across the screen width
      final waveY = math.sin((i / size.width) * 1.0 * 2 * math.pi + phase) * amplitude;
      path.lineTo(i, liquidTopY + waveY);
    }

    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(LiquidSplashClipper oldClipper) => 
      fillLevel != oldClipper.fillLevel || phase != oldClipper.phase;
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
