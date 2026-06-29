import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_widget.dart';
import '../models/sleep_model.dart';
import '../utils/dartstream_manager.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  UserProfile? _profile = DartStreamManager.cachedUserProfile;
  String _userName = 'Sleeper';
  final ScrollController _scrollController = ScrollController();

  // Dynamic theme based on current time
  bool get _isNight => DateTime.now().hour >= 18 || DateTime.now().hour < 6;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('user_name') ?? 'Sleeper';

    if (DartStreamManager.cachedUserProfile != null && mounted) {
      setState(() {
        _profile = DartStreamManager.cachedUserProfile!;
        _userName = localName;
      });
    }

    final profile = await DartStreamManager.loadUserData();
    if (profile != null && mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width <= 768;

    // Time-based colors: Night (navy/dark blue) vs Day (soft light theme)
    final Color scaffoldBg = _isNight ? const Color(0xFF0D1527) : const Color(0xFFF3F4F6);
    final Color cardBg = _isNight ? const Color(0xFF16223F) : Colors.white;
    final Color cardBorder = _isNight ? const Color(0xFF1E2F52) : const Color(0xFFE5E7EB);
    final Color textPrimary = _isNight ? Colors.white : const Color(0xFF1F2937);
    final Color textSecondary = _isNight ? Colors.white70 : const Color(0xFF4B5563);
    
    // Circle background: 2 shades (light and a little dark)
    final Color circleOuter = _isNight ? const Color(0xFF1F2F57) : const Color(0xFFE2E8F0);
    final Color circleInner = _isNight ? const Color(0xFF131D38) : const Color(0xFFF1F5F9);

    final userLevel = _profile?.level ?? 1;
    final totalXp = _profile?.totalXp ?? 180;
    
    final int xpForCurrentLevel = (userLevel - 1) * 300;
    final int xpForNextLevel = userLevel * 300;
    final int xpProgress = totalXp - xpForCurrentLevel;
    final int xpNeeded = xpForNextLevel - xpForCurrentLevel;
    final double levelProgress = (xpProgress / xpNeeded).clamp(0.0, 1.0);
    final int xpRemaining = xpForNextLevel - totalXp;

    final List<Map<String, dynamic>> levelsData = [
      {
        'level': 1,
        'stage': 'mascot',
        'title': 'Level 1: Mascot',
      },
      {
        'level': 2,
        'stage': 'seedling',
        'title': 'Level 2: Seedling',
      },
      {
        'level': 3,
        'stage': 'walking',
        'title': 'Level 3: Walking',
      },
      {
        'level': 4,
        'stage': 'plants',
        'title': 'Level 4: Garden',
      },
      {
        'level': 5,
        'stage': 'waving',
        'title': 'Level 5+: Master',
      },
    ];

    // Visually short/prominent Level Indicator card
    Widget buildMiniLevelCard() {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Level badge in circular container
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                ),
              ),
              child: Center(
                child: Text(
                  'Lvl $userLevel',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_userName\'s Level Progress',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '$xpProgress / $xpNeeded XP',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: levelProgress,
                      minHeight: 5,
                      backgroundColor: _isNight ? const Color(0xFF1E2F52) : const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    xpRemaining <= 0 
                        ? 'Next stage unlocked!' 
                        : '$xpRemaining XP to Level ${userLevel + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: xpRemaining <= 0 ? Colors.greenAccent : textSecondary,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget buildNodeItem(Map<String, dynamic> item, double diameter) {
      final int levelReq = item['level'];
      final String stageKey = item['stage'];
      final bool isUnlocked = userLevel >= levelReq;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular wrapper
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleOuter,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
              border: Border.all(
                color: isUnlocked ? AppTheme.accent : cardBorder,
                width: isUnlocked ? 2.5 : 1.5,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleInner,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Opacity(
                      opacity: isUnlocked ? 1.0 : 0.35,
                      child: PlantWidget(
                        stage: stageKey,
                        size: diameter * 0.72,
                      ),
                    ),
                  ),
                  // Green check badge for unlocked, lock symbol for locked
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUnlocked ? const Color(0xFF10B981) : Colors.black45,
                        border: Border.all(color: cardBg, width: 1.5),
                      ),
                      child: Icon(
                        isUnlocked ? Icons.check : Icons.lock_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          // Short Label
          Text(
            item['title'],
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ],
      );
    }

    // Build the Roadmap containing CustomPaint background path + Stack of positioned nodes
    Widget buildRoadmapWidget(double width) {
      // Dynamic height based on view: Vertical snake path for mobile, horizontal path for web
      final double height = isMobile 
          ? (width * 1.55).clamp(420.0, 580.0) 
          : (width * 0.32).clamp(250.0, 310.0);
      
      final double nodeSize = isMobile ? 74.0 : 80.0;
      
      // Node positions
      final List<Offset> positions = [];
      if (isMobile) {
        positions.add(Offset(width * 0.5, height * 0.08));  // N1
        positions.add(Offset(width * 0.22, height * 0.28)); // N2
        positions.add(Offset(width * 0.78, height * 0.48)); // N3
        positions.add(Offset(width * 0.22, height * 0.68)); // N4
        positions.add(Offset(width * 0.5, height * 0.88));  // N5
      } else {
        positions.add(Offset(width * 0.1, height * 0.4));   // N1
        positions.add(Offset(width * 0.3, height * 0.65));  // N2
        positions.add(Offset(width * 0.5, height * 0.4));   // N3
        positions.add(Offset(width * 0.7, height * 0.65));  // N4
        positions.add(Offset(width * 0.9, height * 0.4));   // N5
      }

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        child: Stack(
          children: [
            // 1. Winding Road Path Background
            Positioned.fill(
              child: CustomPaint(
                painter: RoadmapPainter(isNight: _isNight, isMobile: isMobile),
              ),
            ),
            
            // 2. Positioned Growth Stage Nodes
            Positioned(
              left: positions[0].dx - (nodeSize / 2),
              top: positions[0].dy - (nodeSize / 2),
              child: buildNodeItem(levelsData[0], nodeSize),
            ),
            Positioned(
              left: positions[1].dx - (nodeSize / 2),
              top: positions[1].dy - (nodeSize / 2),
              child: buildNodeItem(levelsData[1], nodeSize),
            ),
            Positioned(
              left: positions[2].dx - (nodeSize / 2),
              top: positions[2].dy - (nodeSize / 2),
              child: buildNodeItem(levelsData[2], nodeSize),
            ),
            Positioned(
              left: positions[3].dx - (nodeSize / 2),
              top: positions[3].dy - (nodeSize / 2),
              child: buildNodeItem(levelsData[3], nodeSize),
            ),
            Positioned(
              left: positions[4].dx - (nodeSize / 2),
              top: positions[4].dy - (nodeSize / 2),
              child: buildNodeItem(levelsData[4], nodeSize),
            ),
          ],
        ),
      );
    }

    final headerRow = Row(
      children: [
        const Icon(Icons.local_florist_rounded, color: AppTheme.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          'Growth Roadmap',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
        ),
      ],
    );

    final subtext = Text(
      'Track your sleep to grow your companion from mascot to master stage.',
      style: GoogleFonts.outfit(
        fontSize: 11,
        color: textSecondary,
        fontWeight: FontWeight.w300,
      ),
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? 420 : 1000, // Responsive full width on web, centered phone on mobile
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerRow,
                  const SizedBox(height: 2),
                  subtext,
                  const SizedBox(height: 12),
                  buildMiniLevelCard(),
                  const SizedBox(height: 14),
                  // Responsive Roadmap Box
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return Scrollbar(
                          controller: _scrollController,
                          thickness: 3.5,
                          radius: const Radius.circular(8.0),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            child: buildRoadmapWidget(w),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Draw a beautiful winding path connecting the stages (Duolingo style roadmap)
class RoadmapPainter extends CustomPainter {
  final bool isNight;
  final bool isMobile;
  RoadmapPainter({required this.isNight, required this.isMobile});

  @override
  void paint(Canvas canvas, Size size) {
    // 2-shade path style (glow/border and clean interior track)
    final outerTrackPaint = Paint()
      ..color = isNight ? const Color(0xFF1E2A4A).withValues(alpha: 0.6) : const Color(0xFFD1FAE5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    final innerLinePaint = Paint()
      ..color = isNight ? AppTheme.accent : const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    if (isMobile) {
      // Center point coordinates for nodes (vertical snake path)
      final p1 = Offset(size.width * 0.5, size.height * 0.08);
      final p2 = Offset(size.width * 0.22, size.height * 0.28);
      final p3 = Offset(size.width * 0.78, size.height * 0.48);
      final p4 = Offset(size.width * 0.22, size.height * 0.68);
      final p5 = Offset(size.width * 0.5, size.height * 0.88);

      path.moveTo(p1.dx, p1.dy);
      
      // Curve 1: N1 to N2
      path.cubicTo(p1.dx, size.height * 0.18, p2.dx, size.height * 0.18, p2.dx, p2.dy);
      // Curve 2: N2 to N3
      path.cubicTo(p2.dx, size.height * 0.38, p3.dx, size.height * 0.38, p3.dx, p3.dy);
      // Curve 3: N3 to N4
      path.cubicTo(p3.dx, size.height * 0.58, p4.dx, size.height * 0.58, p4.dx, p4.dy);
      // Curve 4: N4 to N5
      path.cubicTo(p4.dx, size.height * 0.78, p5.dx, size.height * 0.78, p5.dx, p5.dy);
    } else {
      // Horizontal snake path for desktop/web
      final p1 = Offset(size.width * 0.1, size.height * 0.4);
      final p2 = Offset(size.width * 0.3, size.height * 0.65);
      final p3 = Offset(size.width * 0.5, size.height * 0.4);
      final p4 = Offset(size.width * 0.7, size.height * 0.65);
      final p5 = Offset(size.width * 0.9, size.height * 0.4);

      path.moveTo(p1.dx, p1.dy);
      
      // Curve 1: N1 to N2
      path.cubicTo(size.width * 0.2, p1.dy, size.width * 0.2, p2.dy, p2.dx, p2.dy);
      // Curve 2: N2 to N3
      path.cubicTo(size.width * 0.4, p2.dy, size.width * 0.4, p3.dy, p3.dx, p3.dy);
      // Curve 3: N3 to N4
      path.cubicTo(size.width * 0.6, p3.dy, size.width * 0.6, p4.dy, p4.dx, p4.dy);
      // Curve 4: N4 to N5
      path.cubicTo(size.width * 0.8, p4.dy, size.width * 0.8, p5.dy, p5.dx, p5.dy);
    }

    canvas.drawPath(path, outerTrackPaint);
    canvas.drawPath(path, innerLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
