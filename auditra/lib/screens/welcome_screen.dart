import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/hero_slideshow.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    // Set status bar to transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Slideshow Background with Wave Clip (using full screen size for clipping)
          Positioned.fill(
            child: ClipPath(
              clipper: WelcomeWaveClipper(),
              child: const HeroSlideshow(
                images: [
                  'assets/hero1.webp',
                  'assets/hero2.webp',
                  'assets/hero3.webp',
                ],
              ),
            ),
          ),

          // Text Content (Positioned precisely below the wave)
          Positioned(
            left: 32,
            right: 32,
            top: size.height * 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Welcome to\n',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: 'Auditra',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.primary,
                          letterSpacing: -1.2,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: '.',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                          letterSpacing: -1.2,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: size.width * 0.85,
                  child: Text(
                    'Empowering your field operations with real-time audit tracking, seamless valuation reporting, and intelligent field insights.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Continue Button (Positioned at bottom right)
          Positioned(
            right: 32,
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[300] : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    // Start from left, around 45% down
    path.lineTo(0, size.height * 0.45);

    // Wave stays relatively high, dips down to 55% in the middle
    var firstControlPoint = Offset(size.width * 0.35, size.height * 0.45);
    var firstEndPoint = Offset(size.width * 0.55, size.height * 0.55);

    // Wave dips a bit more to 65% then comes up to 50% on the right
    var secondControlPoint = Offset(size.width * 0.85, size.height * 0.65);
    var secondEndPoint = Offset(size.width, size.height * 0.50);

    path.quadraticBezierTo(
        firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    path.quadraticBezierTo(
        secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
