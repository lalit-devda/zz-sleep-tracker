import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_widget.dart';
import '../models/sleep_model.dart';
import '../utils/dartstream_manager.dart';
import '../utils/toast_helper.dart';



class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accent,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentDark,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ToastHelper.showWarning(context, 'Please select your birthday!');
      return;
    }

    setState(() => _isLoading = true);

    // Calculate age from Date of Birth
    final dob = _selectedDate!;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }

    final name = _nameController.text.trim();
    final email = DartStreamManager.connection?.session.email ?? '';
    final nowTime = DateTime.now();
    final userProfile = UserProfile(
      name: name,
      email: email,
      age: age,
      totalXp: 180,
      level: 1,
      sessions: [
        SleepSession(
          bedTime: nowTime.subtract(const Duration(hours: 14)),
          wakeTime: nowTime.subtract(const Duration(hours: 6)),
          hoursSlept: 8.0,
          xpEarned: 180,
          quality: 5,
        ),
      ],
    );

    try {
      await DartStreamManager.saveUserData(userProfile);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setInt('user_age', age);
      await prefs.setString('user_dob', DateFormat('yyyy-MM-dd').format(dob));
      await prefs.setBool('has_completed_onboarding', true);

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
        ToastHelper.showError(context, 'Failed to save profile on backend. Please check connection.');
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
        // Left Side - Graphic Waving Seedling Card
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
                      Color(0xFFEBF8FF), // Pastel blue
                      Color(0xFFE8F5E9), // Pastel mint green
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Plant widget (Seedling stage)
                    const Center(
                      child: PlantWidget(
                        stage: 'login',
                        size: 200,
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
                            'LET\'S GET STARTED!',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We personalize your plant growth goals and sleep recommendations depending on your age group.',
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

        // Right Side - Onboarding form
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
            Color(0xFFEBF8FF),
            Color(0xFFE8F5E9),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 110,
            child: Center(
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
          // Centered Header
          Text(
            'Welcome! 👋',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us about yourself to begin',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Question 1: What can we call you?
          Text(
            'What should we call you?',
            style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'e.g. Lalit Devda',
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
              if (v == null || v.trim().isEmpty) return 'Enter your name';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Question 2: DOB Birthday
          Text(
            'When is your birthday?',
            style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _selectDate(context),
            child: IgnorePointer(
              child: TextFormField(
                style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: _selectedDate == null
                      ? 'Select Date of Birth'
                      : DateFormat('dd MMMM, yyyy').format(_selectedDate!),
                  hintStyle: GoogleFonts.outfit(
                    color: _selectedDate == null 
                      ? AppTheme.textSecondary.withValues(alpha: 0.5) 
                      : AppTheme.textPrimary,
                  ),
                  fillColor: const Color(0xFFF1F5F9),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Submit Button
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
                      'Begin Journey',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),


        ],
      ),
    );
  }
}
