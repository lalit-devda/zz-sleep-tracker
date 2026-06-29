import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartstream_client/dartstream_client.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_widget.dart';
import '../utils/dartstream_manager.dart';
import '../utils/toast_helper.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // Sign up on DartStream
      await DartStreamManager.signUp(email, password);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', false);
      
      if (mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      String errMsg = 'Registration failed. Please try again.';
      if (e is DartStreamFirebaseAuthException) {
        errMsg = e.message;
      } else if (e is DartStreamApiException) {
        try {
          final decoded = jsonDecode(e.body);
          errMsg = decoded['message'] ?? decoded['error'] ?? e.body;
        } catch (_) {
          errMsg = e.body;
        }
      }
        ToastHelper.showError(context, errMsg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: isDesktop ? _buildDesktopLayout(size) : _buildMobileLayout(size),
      ),
    );
  }

  Widget _buildDesktopLayout(Size size) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE0F2FE),
                      Color(0xFFE8F5E9),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: PlantWidget(
                        stage: 'login',
                        size: 240,
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 40,
                      child: Row(
                        children: [
                          const Icon(Icons.nights_stay_rounded, color: AppTheme.accent, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'zᶻ Sleep Tracker',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      left: 50,
                      right: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'GROW YOUR SANCTUARY',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a free account to track your sleep duration, earn experience points, and nurture your virtual plants.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          width: size.width * 0.5,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 64.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: _buildFormContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0F2FE),
            Color(0xFFE8F5E9),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 110,
            child: const Center(
              child: PlantWidget(
                stage: 'login',
                size: 65,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nights_stay_rounded, color: AppTheme.accent, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Zᶻ Sleep Tracker',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter Your Details Below to Sign Up',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'hello.alex@gmail.com',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Password',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm Password',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Sign up',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Log In',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
