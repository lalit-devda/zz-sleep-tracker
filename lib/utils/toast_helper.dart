import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToastHelper {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, const Color(0xFF10B981), Icons.check_circle_rounded);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, const Color(0xFFEF4444), Icons.error_rounded);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, const Color(0xFFF59E0B), Icons.warning_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, const Color(0xFF3B82F6), Icons.info_rounded);
  }

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: _ToastWidget(
            message: message,
            color: color,
            icon: icon,
            onDismiss: () {
              if (overlayEntry.mounted) {
                overlayEntry.remove();
              }
            },
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    // Auto dismiss after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
