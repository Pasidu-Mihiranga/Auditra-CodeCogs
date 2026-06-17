import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'change_password_screen.dart';
import 'forgot_password_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/hero_slideshow.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _animController;

  // Staggered animations for form elements
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  late Animation<double> _usernameFade;
  late Animation<Offset> _usernameSlide;

  late Animation<double> _passwordFade;
  late Animation<Offset> _passwordSlide;

  late Animation<double> _optionsFade;
  late Animation<Offset> _optionsSlide;

  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Set up staggered intervals
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.5, curve: Curves.easeIn),
      ),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic),
          ),
        );

    _usernameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeIn),
      ),
    );
    _usernameSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _passwordFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );
    _passwordSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _optionsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );
    _optionsSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeIn),
      ),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      await ApiService.getMyRole();
      final role = await ApiService.getUserRole();

      if (!mounted) return;

      final passwordChangeRequired = result['password_change_required'] == true;

      if (passwordChangeRequired) {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                ChangePasswordScreen(isOptional: false, onSuccess: () {}),
          ),
        );
        if (!mounted) return;
        if (changed != true) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(userRole: role ?? 'unassigned'),
        ),
      );
    } else {
      final errorMessage = result['message'] ?? 'Login failed';
      if (errorMessage.contains('Connection') ||
          errorMessage.contains('Network') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('Cannot connect') ||
          errorMessage.contains('SocketException')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connection Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomBgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final notchPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bottomBgColor,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final fixedHeight = constraints.maxHeight < 700
              ? 700.0
              : constraints.maxHeight;

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: fixedHeight,
              child: Stack(
                children: [
                  // Background Slideshow clipped in a wave
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: fixedHeight * 0.52,
                    child: ClipPath(
                      clipper: TopWaveClipper(),
                      child: Container(
                        width: double.infinity,
                        color: AppColors.accent,
                        child: const Stack(
                          children: [
                            Positioned.fill(
                              child: HeroSlideshow(
                                images: [
                                  'assets/hero1.webp',
                                  'assets/hero2.webp',
                                  'assets/hero3.webp',
                                ],
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black54,
                                      Colors.black26,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Soft white gradient glow in the top right corner (blended seamlessly)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: fixedHeight * 0.52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 0.8,
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Small Logo in top-right corner
                  Positioned(
                    top: notchPadding + 16,
                    right: 20,
                    child: Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/Company Logo White.png',
                        width: 75,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.shield_outlined,
                              size: 36,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),

                  // Form Section
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: fixedHeight * 0.08,
                            ), // Push form higher into the wave
                            // Staggered Title Header
                            FadeTransition(
                              opacity: _headerFade,
                              child: SlideTransition(
                                position: _headerSlide,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 60,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Staggered Username Field
                            FadeTransition(
                              opacity: _usernameFade,
                              child: SlideTransition(
                                position: _usernameSlide,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Username',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : const Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _usernameController,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'demo.user',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.normal,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 22,
                                        ),
                                        filled: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE5E7EB),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: AppColors.accent,
                                                width: 2,
                                              ),
                                            ),
                                        border: const UnderlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your username';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Staggered Password Field
                            FadeTransition(
                              opacity: _passwordFade,
                              child: SlideTransition(
                                position: _passwordSlide,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : const Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter your password',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.normal,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 22,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.grey[400],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            );
                                          },
                                        ),
                                        filled: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE5E7EB),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: AppColors.accent,
                                                width: 2,
                                              ),
                                            ),
                                        border: const UnderlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Staggered Remember Me & Forgot Password
                            FadeTransition(
                              opacity: _optionsFade,
                              child: SlideTransition(
                                position: _optionsSlide,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: AppColors.accent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey[400]!,
                                            ),
                                            onChanged: (val) {
                                              setState(
                                                () =>
                                                    _rememberMe = val ?? false,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Remember Me',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : const Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Staggered scale-animated Login Button
                            FadeTransition(
                              opacity: _buttonFade,
                              child: SlideTransition(
                                position: _buttonSlide,
                                child: AnimatedPressButton(
                                  text: 'Login',
                                  isLoading: _isLoading,
                                  onTap: _login,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    // Start from top-left, go down to y=0.75
    path.lineTo(0, size.height * 0.75);

    // Curve down towards the right
    var firstControlPoint = Offset(size.width * 0.35, size.height * 0.75);
    var firstEndPoint = Offset(size.width * 0.60, size.height * 0.90);

    var secondControlPoint = Offset(size.width * 0.85, size.height * 1.05);
    var secondEndPoint = Offset(size.width, size.height * 0.85);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class AnimatedPressButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String text;
  final bool isLoading;

  const AnimatedPressButton({
    super.key,
    required this.onTap,
    required this.text,
    this.isLoading = false,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: (_) => isEnabled ? _controller.forward() : null,
      onTapUp: (_) {
        if (isEnabled) {
          _controller.reverse();
          widget.onTap!();
        }
      },
      onTapCancel: () => isEnabled ? _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isEnabled
                ? AppColors.accent
                : AppColors.accent.withOpacity(0.6),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
