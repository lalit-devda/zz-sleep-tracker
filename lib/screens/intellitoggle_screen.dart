import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/dartstream_manager.dart';
import '../utils/toast_helper.dart';

class IntelliToggleScreen extends StatefulWidget {
  const IntelliToggleScreen({super.key});

  @override
  State<IntelliToggleScreen> createState() => _IntelliToggleScreenState();
}

class _IntelliToggleScreenState extends State<IntelliToggleScreen> {
  // Provider States
  bool _isConnected = false;
  bool _isReconnecting = false;
  String _providerStatusText = 'Provider not ready — init handshake failed. Tap Reconnect.';

  // Targeting Context States
  final List<MapEntry<TextEditingController, TextEditingController>> _attributes = [];

  // Evaluate Flag States
  final _flagKeyController = TextEditingController(text: 'new-dashboard');
  String _flagType = 'boolean';
  bool _isEvaluating = false;

  // Track Event States
  final _eventNameController = TextEditingController(text: 'demo_event');
  final _eventValueController = TextEditingController();
  bool _isTrackLoading = false;

  // Telemetry Logs
  final List<String> _telemetryLogs = [];

  // Flag-aware widget states (derived from dynamic database values)
  bool _newDashboardValue = false;
  String _heroValue = 'control';

  bool get _isNight => DateTime.now().hour >= 18 || DateTime.now().hour < 6;

  @override
  void initState() {
    super.initState();
    _initializeFromConnection();
  }

  void _initializeFromConnection() {
    final conn = DartStreamManager.connection;
    _isConnected = conn != null;
    _providerStatusText = _isConnected
        ? 'Provider ready — connected to IntelliToggle services.'
        : 'Provider not ready — init handshake failed. Tap Reconnect.';

    // Clear old attributes if any
    for (var attr in _attributes) {
      attr.key.dispose();
      attr.value.dispose();
    }
    _attributes.clear();

    _addAttribute('targetingKey', conn?.session.userId ?? 'user-demo-id');
    _addAttribute('email', conn?.session.email ?? 'user@example.com');
    _addAttribute('tenantId', conn?.session.tenantId ?? 'tenant-demo-id');
    _addAttribute('plan', 'premium');

    if (_isConnected) {
      _evaluateFlagOnStartup();
    }
  }

  Future<void> _evaluateFlagOnStartup() async {
    final connection = DartStreamManager.connection;
    if (connection == null) return;
    try {
      final list = await connection.platform.featureFlags.list();
      final match = list.firstWhere(
        (f) => f.key == 'new-dashboard',
        orElse: () => FeatureFlag(key: 'new-dashboard', enabled: false),
      );
      setState(() {
        _newDashboardValue = match.enabled;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (var attr in _attributes) {
      attr.key.dispose();
      attr.value.dispose();
    }
    _flagKeyController.dispose();
    _eventNameController.dispose();
    _eventValueController.dispose();
    super.dispose();
  }

  void _addAttribute([String key = '', String value = '']) {
    setState(() {
      _attributes.add(MapEntry(
        TextEditingController(text: key),
        TextEditingController(text: value),
      ));
    });
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes[index].key.dispose();
      _attributes[index].value.dispose();
      _attributes.removeAt(index);
    });
  }

  Future<void> _reconnect() async {
    setState(() {
      _isReconnecting = true;
      _providerStatusText = 'Re-establishing handshake with server...';
    });

    try {
      // Restore or check session viability
      final restored = await DartStreamManager.tryRestoreSession();
      setState(() {
        _isConnected = restored || DartStreamManager.isLoggedIn;
        _providerStatusText = _isConnected
            ? 'Provider ready — connected to IntelliToggle services.'
            : 'Provider not ready — login session invalid or expired.';
      });
      
      if (_isConnected) {
        _initializeFromConnection();
        if (mounted) {
          ToastHelper.showSuccess(context, 'Connected to live IntelliToggle provider!');
        }
      } else {
        if (mounted) {
          ToastHelper.showError(context, 'Handshake failed: Please log in again.');
        }
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _providerStatusText = 'Handshake failed: $e';
      });
    } finally {
      setState(() {
        _isReconnecting = false;
      });
    }
  }

  void _applyTargeting() {
    final Map<String, String> contextMap = {};
    for (var attr in _attributes) {
      final k = attr.key.text.trim();
      final v = attr.value.text.trim();
      if (k.isNotEmpty) {
        contextMap[k] = v;
      }
    }

    if (mounted) {
      ToastHelper.showSuccess(
        context,
        'Applied targeting context with ${contextMap.length} attributes.',
      );
    }

    // Dynamic widget adjustment
    setState(() {
      final plan = contextMap['plan']?.toLowerCase() ?? 'free';
      _heroValue = plan == 'premium' ? 'variant-b' : 'control';
    });
  }

  Future<void> _evaluateFlag() async {
    final key = _flagKeyController.text.trim();
    if (key.isEmpty) {
      ToastHelper.showWarning(context, 'Please enter a flag key to evaluate.');
      return;
    }

    final connection = DartStreamManager.connection;
    if (connection == null) {
      ToastHelper.showError(context, 'Cannot evaluate flag: Provider not connected.');
      return;
    }

    setState(() => _isEvaluating = true);

    try {
      final list = await connection.platform.featureFlags.list();
      
      // Look for match
      FeatureFlag? match;
      for (var f in list) {
        if (f.key == key) {
          match = f;
          break;
        }
      }

      dynamic evaluatedValue;
      if (match == null) {
        // Flag does not exist, auto-create it as disabled (default false) in the database
        await connection.platform.featureFlags.create(key, false);
        evaluatedValue = false;
        if (mounted) {
          ToastHelper.showInfo(context, 'Flag "$key" not found in database. Auto-created as false.');
        }
      } else {
        evaluatedValue = match.enabled;
      }

      setState(() {
        if (key == 'new-dashboard') {
          _newDashboardValue = evaluatedValue == true;
        }

        // Add to telemetry
        final timeString = DateTime.now().toIso8601String().substring(11, 19);
        _telemetryLogs.insert(0, '[$timeString] evaluated flag "$key" -> $evaluatedValue');
      });

      if (mounted) {
        ToastHelper.showSuccess(context, 'Evaluated flag "$key": $evaluatedValue');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Evaluation failed: $e');
      }
    } finally {
      setState(() => _isEvaluating = false);
    }
  }

  Future<void> _trackEvent() async {
    final eventName = _eventNameController.text.trim();
    if (eventName.isEmpty) {
      ToastHelper.showWarning(context, 'Please enter an event name to track.');
      return;
    }

    final val = _eventValueController.text.trim();
    final connection = DartStreamManager.connection;
    if (connection == null) {
      ToastHelper.showError(context, 'Cannot track event: Provider not connected.');
      return;
    }

    setState(() => _isTrackLoading = true);

    try {
      await DartStreamManager.trackEvent(eventName, {'value': val});

      setState(() {
        final timeString = DateTime.now().toIso8601String().substring(11, 19);
        _telemetryLogs.insert(0, '[$timeString] tracked event "$eventName" with value: ${val.isNotEmpty ? val : 'triggered'}');
      });

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          'Event "$eventName" tracked dynamically in database!',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to track event: $e');
      }
    } finally {
      setState(() => _isTrackLoading = false);
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
                          'IntelliToggle Control Panel',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Dynamic targeting context & feature flag evaluations from DB',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
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
                    _buildProviderCard(cardBg, cardBorder, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _buildTargetingContextCard(cardBg, cardBorder, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _buildEvaluateFlagCard(cardBg, cardBorder, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _buildTrackEventCard(cardBg, cardBorder, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _buildTelemetryCard(cardBg, cardBorder, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _buildWidgetsCard(cardBg, cardBorder, textPrimary, textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Provider details and status card
  Widget _buildProviderCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Provider: IntelliToggle',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  if (_isReconnecting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    )
                  else
                    GestureDetector(
                      onTap: _reconnect,
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Reconnect',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isConnected ? 'READY' : 'ERROR',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _providerStatusText,
            style: GoogleFonts.outfit(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildProviderDetailRow('environment', 'development', textSecondary, textPrimary),
          _buildProviderDetailRow('endpoint', 'https://dev-api.intellitoggle.com', textSecondary, textPrimary),
          _buildProviderDetailRow('timeout', '10s', textSecondary, textPrimary),
          _buildProviderDetailRow('cache TTL', '60s', textSecondary, textPrimary),
          _buildProviderDetailRow('streaming', 'true', textSecondary, textPrimary),
          _buildProviderDetailRow('polling', 'true', textSecondary, textPrimary, isLast: true),
        ],
      ),
    );
  }

  Widget _buildProviderDetailRow(String label, String value, Color labelColor, Color valueColor, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.outfit(fontSize: 13, color: labelColor),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }

  // 2. Targeting Context card
  Widget _buildTargetingContextCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
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
          Text(
            'Targeting context',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Attributes flags are scored against. Edit or add, then apply.',
            style: GoogleFonts.outfit(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attributes.length,
            itemBuilder: (context, index) {
              final attr = _attributes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildAttributeField(attr.key, 'key', cardBorder, textPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildAttributeField(attr.value, 'value', cardBorder, textPrimary),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                      onPressed: () => _removeAttribute(index),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _addAttribute(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add attribute', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
              ),
              ElevatedButton.icon(
                onPressed: _applyTargeting,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text('Apply targeting', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeField(TextEditingController controller, String label, Color borderColor, Color textColor) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.accent),
        ),
      ),
      style: GoogleFonts.outfit(fontSize: 13, color: textColor),
    );
  }

  // 3. Evaluate a flag card
  Widget _buildEvaluateFlagCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
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
          Text(
            'Evaluate a flag',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _flagKeyController,
                  decoration: InputDecoration(
                    labelText: 'Flag key',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, color: textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _flagType,
                    dropdownColor: cardBg,
                    style: GoogleFonts.outfit(fontSize: 13, color: textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'boolean', child: Text('boolean')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _flagType = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isEvaluating ? null : _evaluateFlag,
            icon: _isEvaluating 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow_rounded, size: 16),
            label: Text('Evaluate', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Track an event card
  Widget _buildTrackEventCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
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
          Text(
            'Track an event',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _eventNameController,
                  decoration: InputDecoration(
                    labelText: 'Event name',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, color: textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _eventValueController,
                  decoration: InputDecoration(
                    labelText: 'value (opt)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, color: textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isTrackLoading ? null : _trackEvent,
            icon: _isTrackLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bar_chart_rounded, size: 16),
            label: Text('Track', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Telemetry & hooks card
  Widget _buildTelemetryCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Telemetry · hooks',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (_telemetryLogs.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _telemetryLogs.clear()),
                  child: Row(
                    children: [
                      const Icon(Icons.clear_all_rounded, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_telemetryLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  'No evaluations yet — run one above.',
                  style: GoogleFonts.outfit(fontSize: 13, color: textSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _telemetryLogs.length,
              itemBuilder: (context, index) {
                final logStr = _telemetryLogs[index];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: cardBorder.withValues(alpha: 0.5), width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          logStr,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // 6. Flag-aware widgets card
  Widget _buildWidgetsCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
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
          Text(
            'Flag-aware widgets',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildWidgetRow(
            'New dashboard is ${_newDashboardValue ? 'ON' : 'OFF (default)'}',
            Icons.dashboard_customize_rounded,
            _newDashboardValue ? AppTheme.accent : textSecondary,
            cardBorder,
          ),
          _buildWidgetRow(
            'Hero: $_heroValue',
            Icons.science_rounded,
            _heroValue == 'variant-b' ? AppTheme.accent : textSecondary,
            cardBorder,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetRow(String text, IconData icon, Color iconColor, Color borderColor, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast ? null : BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.outfit(fontSize: 13, color: iconColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
