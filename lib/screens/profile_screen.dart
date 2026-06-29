import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_widget.dart';
import '../models/sleep_model.dart';
import '../utils/dartstream_manager.dart';
import '../utils/image_helper_web.dart';
import '../utils/app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile = DartStreamManager.cachedUserProfile;
  String _selectedPeriod = 'Week';
  String _userName = 'You';

  bool get _isNight => DateTime.now().hour >= 18 || DateTime.now().hour < 6;

  String get _selectedPeriodly {
    if (_selectedPeriod == 'Week') return 'Weekly';
    if (_selectedPeriod == 'Month') return 'Monthly';
    return 'Yearly';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('user_name') ?? 
        DartStreamManager.connection?.session.email?.split('@').first ?? 
        'You';

    // Use cache immediately — never block UI
    if (DartStreamManager.cachedUserProfile != null && mounted) {
      setState(() {
        _profile = DartStreamManager.cachedUserProfile!;
        _userName = localName;
      });
    } else if (mounted) {
      setState(() => _userName = localName);
    }

    // Fetch fresh data silently in background
    final profile = await DartStreamManager.loadUserData();
    if (profile != null && mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  Map<String, dynamic> _getFilteredStats() {
    if (_profile == null || _profile!.sessions.isEmpty) {
      return {
        'totalHours': 0.0,
        'avgHours': 0.0,
        'xpGained': 0,
        'count': 0,
        'avgQuality': 0.0,
      };
    }

    final now = DateTime.now();
    int days = 7;
    if (_selectedPeriod == 'Month') days = 30;
    if (_selectedPeriod == 'Year') days = 365;

    final cutoff = now.subtract(Duration(days: days));
    final filtered = _profile!.sessions.where((s) => s.bedTime.isAfter(cutoff)).toList();

    if (filtered.isEmpty) {
      return {
        'totalHours': 0.0,
        'avgHours': 0.0,
        'xpGained': 0,
        'count': 0,
        'avgQuality': 0.0,
      };
    }

    final totalHours = filtered.fold<double>(0.0, (sum, s) => sum + s.hoursSlept);
    final avgHours = totalHours / filtered.length;
    final xpGained = filtered.fold<int>(0, (sum, s) => sum + s.xpEarned);
    final totalQuality = filtered.fold<int>(0, (sum, s) => sum + s.quality);
    final avgQuality = totalQuality / filtered.length;

    return {
      'totalHours': totalHours,
      'avgHours': avgHours,
      'xpGained': xpGained,
      'count': filtered.length,
      'avgQuality': avgQuality,
    };
  }

  void _shareProgress() {
    if (_profile == null) return;
    
    final level = _profile!.level;
    final stage = _profile!.plantStage.toUpperCase();
    final xp = _profile!.totalXp;
    
    double avgSleep = 0.0;
    if (_profile!.sessions.isNotEmpty) {
      final total = _profile!.sessions.fold<double>(0.0, (sum, s) => sum + s.hoursSlept);
      avgSleep = total / _profile!.sessions.length;
    }
    
    final text = "🌱 zᶻ Sleep Tracker Progress! 💤\n"
        "👤 Name: ${_profile!.name}\n"
        "⭐ Level: $level ($stage Stage)\n"
        "⚡ Total XP: $xp XP\n"
        "📊 Average Sleep: ${avgSleep.toStringAsFixed(1)} hrs\n"
        "Let's grow together!";
        
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress summary copied to clipboard! Share it anywhere! 🚀'),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(message, style: GoogleFonts.outfit(color: Colors.white)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _profile?.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isNight ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Display Name',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: _isNight ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.outfit(
              color: _isNight ? Colors.white : AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: GoogleFonts.outfit(
                color: _isNight ? Colors.white70 : AppTheme.textSecondary,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _isNight ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppTheme.accent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: _isNight ? Colors.white54 : AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                 if (newName.isNotEmpty && _profile != null) {
                  setState(() => _profile!.name = newName);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', newName);
                  AppState.userName.value = newName;
                  await DartStreamManager.saveUserData(_profile!);
                  if (mounted) {
                    Navigator.pop(context);
                    _showToast('Display name updated!');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Save', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAvatarEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isNight ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Change Profile Photo',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: _isNight ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Upload from device
              _avatarOption(
                icon: Icons.cloud_upload_rounded,
                label: 'Upload from Device',
                color: AppTheme.accent,
                onTap: () async {
                  final base64Image = await pickAndConvertImage();
                  if (mounted) Navigator.pop(context);
                  if (base64Image != null && _profile != null && mounted) {
                    setState(() => _profile!.avatar = base64Image);
                    try {
                      await DartStreamManager.saveUserData(_profile!);
                      if (mounted) _showToast('Profile photo updated!');
                    } catch (e) {
                      if (mounted) _showToast('Failed to save photo', isError: true);
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              // Remove photo (reset to default)
              _avatarOption(
                icon: Icons.person_outline_rounded,
                label: 'Use Default Avatar',
                color: _isNight ? Colors.white70 : AppTheme.textSecondary,
                onTap: () async {
                  Navigator.pop(context);
                  if (_profile != null && mounted) {
                    setState(() => _profile!.avatar = null);
                    try {
                      await DartStreamManager.saveUserData(_profile!);
                      if (mounted) _showToast('Reverted to default avatar.');
                    } catch (e) {
                      if (mounted) _showToast('Failed to update', isError: true);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isNight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: _isNight ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildAvatar(UserProfile? profile) {
    final avatarData = profile?.avatar;

    // Uploaded photo (base64 data URI)
    if (avatarData != null && avatarData.startsWith('data:image')) {
      try {
        final uri = Uri.parse(avatarData);
        final imageProvider = MemoryImage(uri.data!.contentAsBytes());
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 2.5),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    }

    // Network image
    if (avatarData != null && avatarData.startsWith('http')) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 2.5),
          image: DecorationImage(image: NetworkImage(avatarData), fit: BoxFit.cover),
        ),
      );
    }

    // Default: person icon with initials fallback
    final initial = (profile != null && profile.name.isNotEmpty)
        ? profile.name[0].toUpperCase()
        : null;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isNight ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 2.5),
      ),
      child: Center(
        child: initial != null
            ? Text(
                initial,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: 40,
                color: AppTheme.accent.withValues(alpha: 0.7),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    double avgSleep = 0.0;
    if (_profile != null && _profile!.sessions.isNotEmpty) {
      final total = _profile!.sessions.fold<double>(0.0, (sum, s) => sum + s.hoursSlept);
      avgSleep = total / _profile!.sessions.length;
    }
    final avgSleepStr = avgSleep == 0.0 ? '0h' : '${avgSleep.toStringAsFixed(1)}h';

    final filteredStats = _getFilteredStats();

    final cardBg = _isNight ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = _isNight ? const Color(0xFF1E2F52) : const Color(0xFFE2E8F0);
    final textPrimaryColor = _isNight ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = _isNight ? Colors.white70 : AppTheme.textSecondary;

    // 2. Left Column: User details card containing plant, details, and stats
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Center(
                child: PlantWidget(
                  stage: _profile?.plantStage ?? 'seedling',
                  size: 140,
                ),
              ),
              const SizedBox(height: 16),
              // Editable Avatar
              Stack(
                children: [
                  _buildAvatar(_profile),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showAvatarEditDialog,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _profile?.name ?? _userName,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    color: AppTheme.accent,
                    onPressed: _showEditNameDialog,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Edit Name',
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 14),
                    color: AppTheme.accent,
                    onPressed: _shareProgress,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Share Progress',
                  ),
                ],
              ),
              Text(
                _profile?.email ?? DartStreamManager.connection?.session.email ?? 'No Email linked',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🌱 Level ${_profile?.level ?? 1} — ${(_profile?.plantStage ?? 'seedling').toUpperCase()} Stage',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentDark,
                  ),
                ),
              ),
              const Divider(height: 32, thickness: 1, color: Colors.grey),
              Row(
                children: [
                  Expanded(child: _statCard(_profile?.totalXp.toString() ?? '0', 'Total XP', AppTheme.xpColor)),
                  const SizedBox(width: 8),
                  Expanded(child: _statCard(_profile?.level.toString() ?? '1', 'Level', AppTheme.accentDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _statCard(avgSleepStr, 'Avg Sleep', AppTheme.sleepBlue)),
                ],
              ),
              if (!isWide) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await DartStreamManager.signOut();
                      if (context.mounted) context.go('/');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    // 3. Right Column: Statistics & settings cards
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPeriodStatsCard(filteredStats),
      ],
    );

    final bodyContent = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: leftColumn),
              const SizedBox(width: 24),
              Expanded(flex: 6, child: rightColumn),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leftColumn,
              const SizedBox(height: 16),
              rightColumn,
            ],
          );

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isWide ? 1050 : 500),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                bodyContent,
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final bg = _isNight ? const Color(0xFF0D1527) : Colors.white.withValues(alpha: 0.8);
    final border = _isNight ? const Color(0xFF1E2F52) : const Color(0xFFE2E8F0);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: ['Week', 'Month', 'Year'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    period,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : (_isNight ? Colors.white70 : AppTheme.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodStatsCard(Map<String, dynamic> stats) {
    final totalHours = stats['totalHours'] as double;
    final avgHours = stats['avgHours'] as double;
    final xpGained = stats['xpGained'] as int;
    final count = stats['count'] as int;
    final avgQuality = stats['avgQuality'] as double;

    final cardBg = _isNight ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = _isNight ? const Color(0xFF1E2F52) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_selectedPeriodly Statistics',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isNight ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count session${count == 1 ? "" : "s"}',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accentDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _miniStatTile(
                Icons.hotel_rounded,
                'Total Sleep',
                '${totalHours.toStringAsFixed(1)} hrs',
                AppTheme.sleepBlue,
              ),
              _miniStatTile(
                Icons.av_timer_rounded,
                'Average Sleep',
                _selectedPeriod == 'Week'
                    ? '${avgHours.toStringAsFixed(1)} hrs/day'
                    : '${avgHours.toStringAsFixed(1)} hrs',
                AppTheme.accentDark,
              ),
              _miniStatTile(
                Icons.star_rounded,
                'Avg Quality',
                avgQuality == 0.0 ? 'N/A' : '${avgQuality.toStringAsFixed(1)} / 5',
                Colors.amber,
              ),
              _miniStatTile(
                Icons.bolt_rounded,
                'XP Earned',
                '+$xpGained XP',
                AppTheme.xpColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatTile(IconData icon, String title, String val, Color color) {
    final tileBg = _isNight ? const Color(0xFF1A263F) : const Color(0xFFF8FAFC);
    final tileBorder = _isNight ? const Color(0xFF2E3E7A) : const Color(0xFFF1F5F9);
    final valColor = _isNight ? Colors.white : AppTheme.textPrimary;
    final titleColor = _isNight ? Colors.white60 : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: titleColor,
                  ),
                ),
                Text(
                  val,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    final bg = _isNight ? const Color(0xFF0F172A) : Colors.white;
    final border = _isNight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final labelColor = _isNight ? Colors.white60 : AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              color: labelColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
