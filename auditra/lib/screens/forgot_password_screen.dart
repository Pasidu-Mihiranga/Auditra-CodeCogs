import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/hero_slideshow.dart';
import 'login_screen.dart'; // To access TopWaveClipper and AnimatedPressButton

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Steps: 1 = Email, 2 = OTP, 3 = New Password
  int _currentStep = 1;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final result = await ApiService.requestPasswordResetOtp(
      email: _emailController.text.trim(),
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'OTP sent to your email'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _currentStep = 2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to send OTP'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await ApiService.verifyPasswordResetOtp(
      email: _emailController.text.trim(),
      otp: _otpController.text.trim(),
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'OTP verified. Set your new password.'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _currentStep = 3);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Invalid or expired OTP'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.confirmPasswordReset(
      email: _emailController.text.trim(),
      newPassword: _passwordController.text,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Password reset successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to reset password'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildStepHeader({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
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
        const SizedBox(height: 16),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep(bool isDark) {
    return Column(
      key: const ValueKey('email_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'Reset Password',
          subtitle: 'Enter your email address and we will send you a 6-digit verification code.',
          isDark: isDark,
        ),
        const SizedBox(height: 36),
        Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'name@company.com',
            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: const Icon(Icons.email_outlined, size: 22),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB), width: 2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
            border: const UnderlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Please enter your email address';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 48),
        AnimatedPressButton(
          text: 'Send OTP',
          isLoading: _isLoading,
          onTap: _requestOtp,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildOtpStep(bool isDark) {
    return Column(
      key: const ValueKey('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'Verify OTP',
          subtitle: 'We sent a 6-digit code to ${_emailController.text}. Please enter it below to proceed.',
          isDark: isDark,
        ),
        const SizedBox(height: 36),
        Text(
          'OTP Code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 16.0,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              color: Colors.grey[400]?.withOpacity(0.5),
              fontWeight: FontWeight.normal,
              fontSize: 24,
              letterSpacing: 16.0,
            ),
            prefixIcon: const Icon(Icons.security_rounded, size: 22),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB), width: 2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
            border: const UnderlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Please enter the 6-digit code';
            if (value.trim().length != 6) return 'The code must be exactly 6 digits';
            return null;
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive it? ",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _requestOtp,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Resend Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        AnimatedPressButton(
          text: 'Verify OTP',
          isLoading: _isLoading,
          onTap: _verifyOtp,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPasswordStep(bool isDark) {
    return Column(
      key: const ValueKey('password_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          title: 'New Password',
          subtitle: 'Create a strong new password containing at least 8 characters.',
          isDark: isDark,
        ),
        const SizedBox(height: 36),
        Text(
          'New Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter new password',
            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB), width: 2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
            border: const UnderlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a password';
            if (value.length < 8) return 'Password must be at least 8 characters';
            return null;
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Re-enter your password',
            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: const Icon(Icons.lock_clock_outlined, size: 22),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB), width: 2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
            border: const UnderlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please confirm your password';
            if (value != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 48),
        AnimatedPressButton(
          text: 'Reset Password',
          isLoading: _isLoading,
          onTap: _resetPassword,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomBgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final notchPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bottomBgColor,
      body: Stack(
        children: [
          // Background Slideshow clipped in a wave (Same as Login)
          ClipPath(
            clipper: TopWaveClipper(),
            child: Container(
              height: size.height * 0.52,
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
          
          // Soft white gradient glow in the top right corner
          Positioned.fill(
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
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.shield_outlined,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Noticeable Premium Frosted Glass Back Button in top-left
          Positioned(
            top: notchPadding + 16,
            left: 16,
            child: GestureDetector(
              onTap: () {
                if (_currentStep > 1) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Form Section (Pushed to bottom half, similar to Login)
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: size.height * 0.18), // Push form higher into the wave
                      
                      // Animated Step Content
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.08, 0.0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: _currentStep == 1
                            ? _buildEmailStep(isDark)
                            : _currentStep == 2
                                ? _buildOtpStep(isDark)
                                : _buildPasswordStep(isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
