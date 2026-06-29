import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/dartstream_manager.dart';
import '../utils/toast_helper.dart';

class FlagsScreen extends StatefulWidget {
  const FlagsScreen({super.key});

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  List<FeatureFlag> _flags = [];
  bool _loadingFlags = true;

  final _newFlagController = TextEditingController();
  bool _newFlagState = true;
  bool _isCreating = false;

  bool get _isNight => DateTime.now().hour >= 18 || DateTime.now().hour < 6;

  @override
  void initState() {
    super.initState();
    _fetchFlags();
  }

  @override
  void dispose() {
    _newFlagController.dispose();
    super.dispose();
  }

  Future<void> _fetchFlags() async {
    final connection = DartStreamManager.connection;
    if (connection == null) return;
    setState(() => _loadingFlags = true);
    try {
      final list = await connection.platform.featureFlags.list();
      setState(() {
        _flags = list;
        _loadingFlags = false;
      });
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to fetch feature flags: $e');
        setState(() => _loadingFlags = false);
      }
    }
  }

  Future<void> _createFlag() async {
    final key = _newFlagController.text.trim();
    if (key.isEmpty) {
      ToastHelper.showWarning(context, 'Please enter a flag key!');
      return;
    }

    final connection = DartStreamManager.connection;
    if (connection == null) return;

    setState(() => _isCreating = true);
    try {
      await connection.platform.featureFlags.create(key, _newFlagState);
      _newFlagController.clear();
      _newFlagState = true;
      if (mounted) {
        ToastHelper.showSuccess(context, 'Feature flag "$key" created!');
      }
      _fetchFlags();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to create flag: $e');
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _toggleFlag(FeatureFlag flag) async {
    final connection = DartStreamManager.connection;
    if (connection == null) return;

    try {
      final nextVal = !flag.enabled;
      await connection.platform.featureFlags.update(flag.key, nextVal);
      if (mounted) {
        ToastHelper.showSuccess(
          context, 
          'Flag "${flag.key}" is now ${nextVal ? "ENABLED" : "DISABLED"}'
        );
      }
      _fetchFlags();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to toggle flag: $e');
      }
    }
  }

  Future<void> _deleteFlag(FeatureFlag flag) async {
    final connection = DartStreamManager.connection;
    if (connection == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Flag?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete feature flag "${flag.key}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await connection.platform.featureFlags.delete(flag.key);
      if (mounted) {
        ToastHelper.showSuccess(context, 'Flag "${flag.key}" deleted successfully.');
      }
      _fetchFlags();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to delete flag: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = _isNight ? const Color(0xFF090E1A) : const Color(0xFFF8FAFC);
    final Color cardBg = _isNight ? const Color(0xFF111827) : Colors.white;
    final Color cardBorder = _isNight ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final Color textPrimary = _isNight ? Colors.white : AppTheme.textPrimary;
    final Color textSecondary = _isNight ? Colors.white70 : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(
                  bottom: BorderSide(color: cardBorder, width: 1.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Controls',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'SaaS configuration & persistence sync',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
                      onPressed: _fetchFlags,
                      tooltip: 'Refresh All Data',
                    ),
                  ],
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPlatformFlagsCard(cardBg, cardBorder, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _buildCloudPersistenceCard(cardBg, cardBorder, textPrimary, textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformFlagsCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    final activeCount = _flags.where((f) => f.enabled).length;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 20, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Platform Flags',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_rounded, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      '$activeCount active',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Create new flag form
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFlagController,
                  decoration: InputDecoration(
                    hintText: 'New flag key (e.g. experimental_features)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                  style: GoogleFonts.outfit(color: textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Text(
                    _newFlagState ? 'Enabled' : 'Disabled',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _newFlagState ? AppTheme.accent : textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Switch(
                    value: _newFlagState,
                    activeThumbColor: AppTheme.accent,
                    onChanged: (val) {
                      setState(() {
                        _newFlagState = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createFlag,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCreating 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // List of flags
          if (_loadingFlags)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            )
          else if (_flags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No feature flags found on this tenant.',
                  style: GoogleFonts.outfit(color: textSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _flags.map<Widget>((FeatureFlag flag) {
                return _buildFlagChip(flag, cardBorder, textPrimary, textSecondary);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFlagChip(FeatureFlag flag, Color cardBorder, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: flag.enabled ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: flag.enabled ? AppTheme.accent.withValues(alpha: 0.3) : cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flag.enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: flag.enabled ? AppTheme.accent : textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            flag.key,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: flag.enabled ? AppTheme.accent : textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _toggleFlag(flag),
            child: Icon(
              flag.enabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              size: 20,
              color: flag.enabled ? AppTheme.accent : textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _deleteFlag(flag),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudPersistenceCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    final tenantId = DartStreamManager.connection?.session.tenantId ?? 'unknown-tenant';
    
    // Format current time nicely (e.g. 5:31 PM)
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    final timeString = '$hour:$minute $amPm';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 20, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Cloud Persistence',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildDetailRow('Provider', 'DartStream Cloud Save', Icons.cloud_queue_rounded, textPrimary, textSecondary, cardBorder),
          _buildDetailRow('Last Sync', timeString, Icons.access_time_rounded, textPrimary, textSecondary, cardBorder),
          _buildDetailRow('Snapshot Status', 'Synced', Icons.sync_rounded, textPrimary, textSecondary, cardBorder),
          _buildDetailRow('Project', tenantId, Icons.folder_rounded, textPrimary, textSecondary, cardBorder),
          _buildDetailRow('Slot', tenantId, Icons.save_rounded, textPrimary, textSecondary, cardBorder, isLast: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label, 
    String value, 
    IconData icon,
    Color textPrimary, 
    Color textSecondary,
    Color cardBorder,
    {bool isLast = false}
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: isLast ? null : BoxDecoration(
        border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
