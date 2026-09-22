import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/photo_upload_helper.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../state/theme_provider.dart';
import 'doctor_chambers_screen.dart';

class DoctorShell extends StatefulWidget {
  final AuthProvider auth;

  const DoctorShell({Key? key, required this.auth}) : super(key: key);

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _DoctorDashboardTab(auth: widget.auth),
      const _DoctorQueueTab(),
      const _DoctorAppointmentsTab(),
      _DoctorProfileTab(auth: widget.auth),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit MEDIQ'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _tabs[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.bottomBarColor(context),
            border: Border(
              top: BorderSide(
                color: AppColors.borderColor(context),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.bottomBarColor(context),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textLight,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.queue_outlined),
                  activeIcon: Icon(Icons.queue_rounded),
                  label: 'Chamber Queue',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_note_outlined),
                  activeIcon: Icon(Icons.event_note_rounded),
                  label: 'Appointments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Doctor Dashboard Tab (Modern Medica UI)
// ---------------------------------------------------------------------------
class _DoctorDashboardTab extends StatefulWidget {
  final AuthProvider auth;

  const _DoctorDashboardTab({Key? key, required this.auth}) : super(key: key);

  @override
  State<_DoctorDashboardTab> createState() => _DoctorDashboardTabState();
}

class _DoctorDashboardTabState extends State<_DoctorDashboardTab> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  int? _selectedChamberId;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard([int? cid]) async {
    if (cid != null) _selectedChamberId = cid;
    try {
      final query = _selectedChamberId != null ? '?chamber_id=$_selectedChamberId' : '';
      final res = await ApiService.get('/doctor/dashboard$query');
      if (mounted) {
        setState(() {
          _dashboardData = res;
          final chambers = res?['chambers'] as List?;
          if (chambers != null && chambers.isNotEmpty) {
            final validIds = chambers
                .map((c) => int.tryParse(c['id']?.toString() ?? ''))
                .whereType<int>()
                .toList();
            if (_selectedChamberId == null || !validIds.contains(_selectedChamberId)) {
              _selectedChamberId = validIds.isNotEmpty ? validIds.first : null;
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAvailability(String status, {String reason = '', String liveStatus = 'AVAILABLE'}) async {
    final firstCid = ((_dashboardData?['chambers'] as List?)?.firstOrNull?['id']);
    final parsedFirst = firstCid != null ? int.tryParse(firstCid.toString()) : null;
    final cid = _selectedChamberId ?? parsedFirst;
    if (cid == null) return;

    try {
      await ApiService.post('/doctor/availability/toggle', {
        'chamber_id': cid,
        'status': status,
        'reason': reason,
        'live_status': liveStatus,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason.isNotEmpty ? 'Session: $reason' : 'Session status: $status'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadDashboard();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _dashboardData?['stats'] ?? {};
    final chambers = (_dashboardData?['chambers'] as List?) ?? [];
    final avail = stats['availability'] ?? 'ON';
    final statusNote = stats['status_note']?.toString();
    final doctorName = widget.auth.currentUser?.fullName ?? 'Doctor';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            AppAvatar(
              imageUrl: widget.auth.currentUser?.profilePhoto,
              name: doctorName,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chamber Console',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Dr. $doctorName',
                    style: TextStyle(fontSize: 16, color: AppColors.textColor(context), fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboard();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Chamber Switcher Row (if doctor has chambers)
            if (chambers.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final validChambers = chambers
                      .where((c) => int.tryParse(c['id']?.toString() ?? '') != null)
                      .toList();
                  final validIds = validChambers
                      .map((c) => int.parse(c['id'].toString()))
                      .toSet();
                  final dropdownVal = validIds.contains(_selectedChamberId)
                      ? _selectedChamberId
                      : (validIds.isNotEmpty ? validIds.first : null);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderColor(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: dropdownVal,
                              isExpanded: true,
                              dropdownColor: AppColors.cardColor(context),
                              items: validChambers.map<DropdownMenuItem<int>>((c) {
                                final cid = int.parse(c['id'].toString());
                                return DropdownMenuItem<int>(
                                  value: cid,
                                  child: Text(
                                    '${c['name']} (${c['city_name'] ?? c['area_name'] ?? 'Chamber'})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  _loadDashboard(val);
                                }
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.primary),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DoctorChambersScreen(auth: widget.auth)),
                          ).then((_) => _loadDashboard()),
                          tooltip: 'Manage Chambers',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Active Break Alert Banner (Shown when PAUSED)
            if (avail == 'PAUSED') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      (statusNote?.contains('Prayer') ?? false)
                          ? '🕌'
                          : ((statusNote?.contains('Meal') ?? false) ? '🍽️' : '⏸️'),
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusNote ?? 'Chamber Session Paused',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Bookings held. Waiting patients are notified.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _toggleAvailability('ON', reason: 'Consultation Resumed', liveStatus: 'AVAILABLE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Resume 🟢', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Session Status Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'CHAMBER SESSION STATUS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMutedColor(context), letterSpacing: 0.8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: avail == 'ON'
                              ? AppColors.successLight
                              : (avail == 'PAUSED' ? const Color(0xFFFEF3C7) : AppColors.dangerLight),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            avail == 'ON' ? 'Active & Consulting' : (avail == 'PAUSED' ? 'Paused' : 'Offline'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: avail == 'ON'
                                  ? AppColors.success
                                  : (avail == 'PAUSED' ? const Color(0xFFB45309) : AppColors.danger),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Session Action Presets (Prayer Break, Meal Break, Pause, Online, Close)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('🟢 Online', AppColors.success, avail == 'ON', () {
                        _toggleAvailability('ON', reason: 'Chamber Online', liveStatus: 'AVAILABLE');
                      }),
                      _buildPresetChip('🕌 Prayer Break', const Color(0xFFD97706), avail == 'PAUSED' && (statusNote?.contains('Prayer') ?? false), () {
                        _toggleAvailability('PAUSED', reason: '🕌 Prayer Break (নামাজের বিরতি)', liveStatus: 'SHORT_BREAK');
                      }),
                      _buildPresetChip('🍽️ Meal Break', const Color(0xFFD97706), avail == 'PAUSED' && (statusNote?.contains('Meal') ?? false), () {
                        _toggleAvailability('PAUSED', reason: '🍽️ Meal Break (খাওয়ার বিরতি)', liveStatus: 'SHORT_BREAK');
                      }),
                      _buildPresetChip('⏸️ Pause', const Color(0xFFF59E0B), avail == 'PAUSED' && !(statusNote?.contains('Prayer') ?? false) && !(statusNote?.contains('Meal') ?? false), () {
                        _toggleAvailability('PAUSED', reason: '⏸️ Short Break (বিরতি)', liveStatus: 'SHORT_BREAK');
                      }),
                      _buildPresetChip('🛑 Close', AppColors.danger, avail == 'OFF', () {
                        _toggleAvailability('OFF', reason: 'Chamber Session Closed', liveStatus: 'FINISHED');
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Metrics 2x2 Grid
            Row(
              children: [
                _buildDoctorMetricTile(
                  'Current Token',
                  stats['current_token']?.toString() ?? '--',
                  Icons.confirmation_number_outlined,
                  AppColors.primary,
                ),
                const SizedBox(width: 12),
                _buildDoctorMetricTile(
                  'In Waiting Queue',
                  '${stats['waiting_count'] ?? 0}',
                  Icons.people_alt_outlined,
                  const Color(0xFFF59E0B),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDoctorMetricTile(
                  'Consulted Today',
                  '${stats['completed_count'] ?? 0}',
                  Icons.check_circle_outline_rounded,
                  AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildDoctorMetricTile(
                  'Total Booked',
                  '${stats['total_booked'] ?? 0}',
                  Icons.calendar_today_rounded,
                  AppColors.isDark(context) ? const Color(0xFF60A5FA) : AppColors.primaryDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chamber Capacity Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Chamber Patient Capacity',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textColor(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${stats['remaining'] ?? 0} slots left',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (stats['capacity'] != null && stats['capacity'] > 0)
                          ? ((stats['total_booked'] ?? 0) / stats['capacity']).clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: AppColors.inputFillColor(context),
                      color: AppColors.primary,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Booked: ${stats['total_booked'] ?? 0} / ${stats['capacity'] ?? 20} Patients',
                          style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Max: ${stats['capacity'] ?? 20}',
                          style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.inputFillColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.borderColor(context),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textColor(context),
          ),
        ),
      ),
    );
  }


  Widget _buildDoctorMetricTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context))),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Doctor Queue Tab (Live Chamber Queue Management)
// ---------------------------------------------------------------------------
class _DoctorQueueTab extends StatefulWidget {
  const _DoctorQueueTab({Key? key}) : super(key: key);

  @override
  State<_DoctorQueueTab> createState() => _DoctorQueueTabState();
}

class _DoctorQueueTabState extends State<_DoctorQueueTab> {
  Map<String, dynamic>? _queueData;
  Map<String, dynamic>? _dashboardStats;
  List<dynamic> _chambers = [];
  int? _selectedChamberId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue([int? cid]) async {
    if (cid != null) _selectedChamberId = cid;
    try {
      final dash = await ApiService.get('/doctor/dashboard' + (_selectedChamberId != null ? '?chamber_id=$_selectedChamberId' : ''));
      _chambers = (dash?['chambers'] as List?) ?? [];
      _dashboardStats = dash?['stats'] as Map<String, dynamic>?;
      if (_chambers.isNotEmpty) {
        final validIds = _chambers
            .map((c) => int.tryParse(c['id']?.toString() ?? ''))
            .whereType<int>()
            .toList();
        if (_selectedChamberId == null || !validIds.contains(_selectedChamberId)) {
          _selectedChamberId = validIds.isNotEmpty ? validIds.first : null;
        }
      }
      final query = _selectedChamberId != null ? '?chamber_id=$_selectedChamberId' : '';
      final res = await ApiService.get('/queue/doctor/today$query');
      if (mounted) {
        setState(() {
          _queueData = res?['queue'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBreak(String status, {String reason = '', String liveStatus = 'AVAILABLE'}) async {
    final firstCid = _chambers.isNotEmpty ? int.tryParse(_chambers[0]['id']?.toString() ?? '') : 1;
    final cid = _selectedChamberId ?? firstCid ?? 1;
    try {
      await ApiService.post('/doctor/availability/toggle', {
        'chamber_id': cid,
        'status': status,
        'reason': reason,
        'live_status': liveStatus,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason.isNotEmpty ? 'Session: $reason' : 'Status: $status'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadQueue();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final current = _queueData?['current'];
    final called = _queueData?['called'];
    final waiting = (_queueData?['waiting'] as List?) ?? [];
    final avail = _dashboardStats?['availability'] ?? 'ON';
    final statusNote = _dashboardStats?['status_note']?.toString();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('Live Chamber Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadQueue();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQueue,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Chamber Switcher Row (if doctor has multiple chambers)
            if (_chambers.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final validChambers = _chambers
                      .where((c) => int.tryParse(c['id']?.toString() ?? '') != null)
                      .toList();
                  final validIds = validChambers
                      .map((c) => int.parse(c['id'].toString()))
                      .toSet();
                  final dropdownVal = validIds.contains(_selectedChamberId)
                      ? _selectedChamberId
                      : (validIds.isNotEmpty ? validIds.first : null);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderColor(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: dropdownVal,
                              isExpanded: true,
                              dropdownColor: AppColors.cardColor(context),
                              items: validChambers.map<DropdownMenuItem<int>>((c) {
                                final cid = int.parse(c['id'].toString());
                                return DropdownMenuItem<int>(
                                  value: cid,
                                  child: Text(
                                    '${c['name']} (${c['city_name'] ?? c['area_name'] ?? 'Chamber'})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  _loadQueue(val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Active Break Banner
            if (avail == 'PAUSED') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      (statusNote?.contains('Prayer') ?? false)
                          ? '🕌'
                          : ((statusNote?.contains('Meal') ?? false) ? '🍽️' : '⏸️'),
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusNote ?? 'Chamber Session Paused',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Queue calls held. Patients are notified.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _toggleBreak('ON', reason: 'Consultation Resumed', liveStatus: 'AVAILABLE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Resume 🟢', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Quick Break Controls Bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Row(
                children: [
                  Text(
                    'Quick Breaks:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQueueBreakChip('🟢 Online', AppColors.success, () {
                            _toggleBreak('ON', reason: 'Online', liveStatus: 'AVAILABLE');
                          }),
                          const SizedBox(width: 6),
                          _buildQueueBreakChip('🕌 Prayer', const Color(0xFFD97706), () {
                            _toggleBreak('PAUSED', reason: '🕌 Prayer Break (নামাজের বিরতি)', liveStatus: 'SHORT_BREAK');
                          }),
                          const SizedBox(width: 6),
                          _buildQueueBreakChip('🍽️ Meal', const Color(0xFFD97706), () {
                            _toggleBreak('PAUSED', reason: '🍽️ Meal Break (খাওয়ার বিরতি)', liveStatus: 'SHORT_BREAK');
                          }),
                          const SizedBox(width: 6),
                          _buildQueueBreakChip('⏸️ Pause', const Color(0xFFF59E0B), () {
                            _toggleBreak('PAUSED', reason: '⏸️ Short Break (বিরতি)', liveStatus: 'SHORT_BREAK');
                          }),
                          const SizedBox(width: 6),
                          _buildQueueBreakChip('🛑 Close', AppColors.danger, () {
                            _toggleBreak('OFF', reason: 'Session Closed', liveStatus: 'FINISHED');
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Current Consulting Patient Card
            if (current != null) ...[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF246BFD), Color(0xFF1952C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CURRENTLY IN CHAMBER',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          current['token_display'] ?? '',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
                        ),
                      ],
                    ),
                    Text(
                      current['patient_name'] ?? 'Patient',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await ApiService.post('/queue/doctor/complete', {'appointment_id': current['id']});
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Consultation completed (Paper Rx / প্রেসক্রিপশন ছাড়া সম্পন্ন)'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadQueue();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('✍️ Complete Visit (Paper Rx / প্রেসক্রিপশন ছাড়া)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openDigitalPrescriptionSheet(context, current),
                      icon: const Icon(Icons.description_outlined, size: 18, color: Colors.white),
                      label: const Text('💻 Digital Rx (প্রেসক্রিপশন তৈরি)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70, width: 1.2),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Called Patient (Waiting at Door)
            if (called != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CALLED TO ENTER',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: 0.8),
                        ),
                        Text(
                          called['token_display'] ?? '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      called['patient_name'] ?? 'Patient',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () async {
                              await ApiService.post('/queue/doctor/start', {'appointment_id': called['id']});
                              _loadQueue();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB45309),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Start Visit', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await ApiService.post('/queue/doctor/complete', {'appointment_id': called['id']});
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Consultation completed (Paper Rx).'), backgroundColor: AppColors.success),
                                );
                                _loadQueue();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('✍️ Paper Rx', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () async {
                              await ApiService.post('/queue/doctor/skip', {'appointment_id': called['id']});
                              _loadQueue();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB45309),
                              side: const BorderSide(color: Color(0xFFB45309)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Skip'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () async {
                              await ApiService.post('/queue/doctor/no-show', {'appointment_id': called['id']});
                              _loadQueue();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('No-Show'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Call Next Patient Primary Action Button
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final cid = _selectedChamberId ?? (_chambers.isNotEmpty ? _chambers[0]['id'] : 1);
                  final res = await ApiService.post('/queue/doctor/call-next', {'chamber_id': cid});
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Called token ${res['token_display']}'), backgroundColor: AppColors.success),
                  );
                  _loadQueue();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                }
              },
              icon: const Icon(Icons.campaign_rounded, size: 22),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Call Next Patient in Queue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),

            // Waiting Queue Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Awaiting Chamber Turn',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textColor(context)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLightColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${waiting.length} Waiting',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (waiting.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Text(
                  'No patients currently waiting in the chamber queue.',
                  style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                ),
              )
            else
              ...waiting.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderColor(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLightColor(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              p['token_display'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['patient_name'] ?? 'Patient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('Status: ${p['status']}', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.inputFillColor(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('In Line', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context))),
                        ),
                      ],
                    ),
                  )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueBreakChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  void _openDigitalPrescriptionSheet(BuildContext context, dynamic current) {
    final token = current['token_display'] ?? '';
    final patientName = current['patient_name'] ?? 'Patient';
    final aptId = current['id'];

    final symptomsCtrl = TextEditingController();
    final diagnosisCtrl = TextEditingController();
    final adviceCtrl = TextEditingController();

    final List<Map<String, String>> medicines = [
      {'name': 'Tab. Pantoprazole 20mg', 'dose': '1 tablet', 'freq': '1+0+1', 'dur': '14 days'}
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Sheet Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          token,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textColor(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Digital Prescription (ডিজিটাল প্রেসক্রিপশন)',
                              style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Form body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Chief Complaints (Symptoms)
                      Text(
                        'Chief Complaints (লক্ষ্মণ / C/C):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: symptomsCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Fever for 3 days, dry cough...',
                          fillColor: AppColors.inputFillColor(context),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ['Fever (জ্বর)', 'Dry Cough (শুকনো কাশি)', 'Chest Pain (বুকে ব্যথা)', 'Headache (মাথাব্যথা)', 'Fatigue (দুর্বলতা)'].map((s) {
                          return InkWell(
                            onTap: () {
                              final curr = symptomsCtrl.text.trim();
                              symptomsCtrl.text = curr.isEmpty ? s : '$curr, $s';
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLightColor(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('+$s', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Diagnosis
                      Text(
                        'Diagnosis (রোগ নির্ণয়):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: diagnosisCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Acute Upper Respiratory Tract Infection',
                          fillColor: AppColors.inputFillColor(context),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Medicines list
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Medicines (Rx ওষুধ):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context)),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                medicines.add({'name': '', 'dose': '1 tab', 'freq': '1+0+1', 'dur': '7 days'});
                              });
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Drug', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      ...medicines.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final med = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.inputFillColor(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderColor(context)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: med['name'],
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        hintText: 'Medicine name (e.g. Tab Napa 500mg)',
                                        border: InputBorder.none,
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      onChanged: (val) => med['name'] = val,
                                    ),
                                  ),
                                  if (medicines.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setSheetState(() => medicines.removeAt(idx)),
                                    ),
                                ],
                              ),
                              const Divider(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: med['dose'],
                                      decoration: const InputDecoration(isDense: true, hintText: 'Dose', border: InputBorder.none),
                                      style: const TextStyle(fontSize: 11),
                                      onChanged: (val) => med['dose'] = val,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: med['freq'],
                                      decoration: const InputDecoration(isDense: true, hintText: '1+0+1', border: InputBorder.none),
                                      style: const TextStyle(fontSize: 11),
                                      onChanged: (val) => med['freq'] = val,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: med['dur'],
                                      decoration: const InputDecoration(isDense: true, hintText: '7 days', border: InputBorder.none),
                                      style: const TextStyle(fontSize: 11),
                                      onChanged: (val) => med['dur'] = val,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      // Advice
                      Text(
                        'Advice (উপদেশ):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: adviceCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Drink plenty of warm water, take rest...',
                          fillColor: AppColors.inputFillColor(context),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Submit Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor(context),
                    border: Border(top: BorderSide(color: AppColors.borderColor(context))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await ApiService.post('/queue/doctor/complete', {'appointment_id': aptId});
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Completed with Handwritten Rx.'), backgroundColor: AppColors.success),
                              );
                              _loadQueue();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Paper Rx Only', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              // 1. Submit consultation & digital prescription
                              final validMeds = medicines.where((m) => (m['name'] ?? '').trim().isNotEmpty).toList();
                              await ApiService.post('/consultations', {
                                'appointment_id': aptId,
                                'symptoms': symptomsCtrl.text.trim(),
                                'clinical_notes': diagnosisCtrl.text.trim(),
                                'advice': adviceCtrl.text.trim(),
                                'medicines': validMeds.map((m) => {
                                  'medicine_name': m['name'],
                                  'dosage': m['dose'],
                                  'frequency': m['freq'],
                                  'duration': m['dur'],
                                  'instructions': 'After meals',
                                }).toList(),
                              });

                              // 2. Complete consultation in queue
                              await ApiService.post('/queue/doctor/complete', {'appointment_id': aptId});

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Digital Rx issued & consultation completed!'), backgroundColor: AppColors.success),
                              );
                              _loadQueue();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Save & Issue Digital Rx', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Doctor Appointments & Profile Tabs
// ---------------------------------------------------------------------------
class _DoctorAppointmentsTab extends StatelessWidget {
  const _DoctorAppointmentsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('Today\'s Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLightColor(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Live Chamber Queue Active',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textColor(context)),
              ),
              const SizedBox(height: 6),
              Text(
                'All patient serials for today are managed directly through the Live Chamber Queue tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorProfileTab extends StatelessWidget {
  final AuthProvider auth;

  const _DoctorProfileTab({Key? key, required this.auth}) : super(key: key);

  void _showCenteredLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.dangerLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                'Sure You Want to Leave?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out from your Doctor Console?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLightColor(context),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await auth.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Yes, Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    final fullName = user?.fullName ?? 'Doctor';
    final phone = user?.phone ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('Doctor Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ThemeToggleButton(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Doctor Avatar & Info
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    AppAvatar(
                      imageUrl: user?.profilePhoto,
                      name: fullName,
                      radius: 46,
                      fontSize: 34,
                      onTap: () => PhotoUploadHelper.showPhotoActionSheet(context: context, auth: auth),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => PhotoUploadHelper.showPhotoActionSheet(context: context, auth: auth),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Dr. $fullName',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLightColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Verified Doctor Console',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Appearance / Dark Mode Selector Tile
          ListenableBuilder(
            listenable: ThemeProvider(),
            builder: (ctx, _) {
              final isDark = ThemeProvider().isDark(ctx);
              final mode = ThemeProvider().themeMode;
              final modeLabel = mode == ThemeMode.system
                  ? 'System Default'
                  : (isDark ? 'Dark Mode' : 'Light Mode');

              return _buildMenuTile(
                ctx,
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                'Appearance / Theme',
                () => ThemeSelectorDialog.show(ctx),
                subtitle: Text(
                  modeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                trailing: Switch(
                  value: isDark,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    ThemeProvider().setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              );
            },
          ),

          // Menu Options
          _buildMenuTile(context, Icons.person_outline_rounded, 'Edit Doctor Profile', () => _showEditDoctorProfileModal(context)),
          _buildMenuTile(context, Icons.camera_alt_outlined, 'Change Profile Photo', () => PhotoUploadHelper.showPhotoActionSheet(context: context, auth: auth)),
          _buildMenuTile(context, Icons.verified_user_rounded, 'BMDC Medical Registration', () {}),
          _buildMenuTile(
            context,
            Icons.meeting_room_rounded,
            'Chamber Management & Timings',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DoctorChambersScreen(auth: auth)),
            ),
          ),
          _buildMenuTile(context, Icons.receipt_rounded, 'Prescription Templates', () {}),
          _buildMenuTile(context, Icons.notifications_none_rounded, 'Chamber Notification Alerts', () {}),
          _buildMenuTile(context, Icons.help_outline_rounded, 'Support & Assistance', () {}),
          const SizedBox(height: 10),
          _buildMenuTile(
            context,
            Icons.logout_rounded,
            'Sign Out',
            () => _showCenteredLogoutDialog(context),
            isDanger: true,
          ),
        ],
      ),
    );
  }

  void _showEditDoctorProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorEditProfileSheet(auth: auth),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDanger = false,
    Widget? trailing,
    Widget? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDanger ? AppColors.dangerLight : AppColors.primaryLightColor(context),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDanger ? AppColors.danger : AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDanger ? AppColors.danger : AppColors.textColor(context),
          ),
        ),
        subtitle: subtitle,
        trailing: trailing ?? Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDanger ? AppColors.danger : AppColors.textLight,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Doctor Edit Profile Bottom Sheet Modal
// ---------------------------------------------------------------------------
class _DoctorEditProfileSheet extends StatefulWidget {
  final AuthProvider auth;

  const _DoctorEditProfileSheet({Key? key, required this.auth}) : super(key: key);

  @override
  State<_DoctorEditProfileSheet> createState() => _DoctorEditProfileSheetState();
}

class _DoctorEditProfileSheetState extends State<_DoctorEditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _desigController;
  late final TextEditingController _expController;
  late final TextEditingController _feeController;
  late final TextEditingController _fuFeeController;
  late final TextEditingController _bioController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _desigController = TextEditingController(text: 'MBBS, FCPS');
    _expController = TextEditingController(text: '8');
    _feeController = TextEditingController(text: '1000');
    _fuFeeController = TextEditingController(text: '600');
    _bioController = TextEditingController();
    _loadDoctorProfile();
  }

  Future<void> _loadDoctorProfile() async {
    try {
      final res = await ApiService.get('/doctor/profile');
      if (res != null && mounted) {
        setState(() {
          if (res['doctor_name'] != null) _nameController.text = res['doctor_name'];
          if (res['email'] != null) _emailController.text = res['email'];
          if (res['phone'] != null) _phoneController.text = res['phone'];
          if (res['designation'] != null) _desigController.text = res['designation'];
          if (res['experience_years'] != null) _expController.text = '${res['experience_years']}';
          if (res['consultation_fee'] != null) _feeController.text = '${res['consultation_fee']}';
          if (res['follow_up_fee'] != null) _fuFeeController.text = '${res['follow_up_fee']}';
          if (res['bio'] != null) _bioController.text = res['bio'];
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final desig = _desigController.text.trim();

    if (name.isEmpty || phone.isEmpty || desig.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'full_name': name,
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'phone': phone,
        'designation': desig,
        'experience_years': int.tryParse(_expController.text.trim()) ?? 0,
        'consultation_fee': double.tryParse(_feeController.text.trim()) ?? 0.0,
        'follow_up_fee': double.tryParse(_fuFeeController.text.trim()) ?? 0.0,
        'bio': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      };

      await ApiService.put('/doctor/profile', payload);
      await widget.auth.updateUserInfo(
        fullName: name,
        email: _emailController.text.trim(),
        phone: phone,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor profile updated successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _desigController.dispose();
    _expController.dispose();
    _feeController.dispose();
    _fuFeeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.borderDarkColor(context), borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Doctor Profile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textColor(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Doctor Full Name
                Text('Doctor Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Dr. Firstname Lastname',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Contact Phone & Email
                Text('Contact Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '+88017...',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'doctor@example.com',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Designation & Experience
                Text('Designation & Medical Degrees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _desigController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  decoration: InputDecoration(
                    hintText: 'e.g. MBBS, FCPS (Cardiology), MD',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.school_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Consultation Fee (৳)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _feeController,
                            style: TextStyle(color: AppColors.textColor(context)),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '1000',
                              hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                              prefixIcon: Icon(Icons.payments_outlined, color: AppColors.textLightColor(context)),
                              fillColor: AppColors.inputFillColor(context),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Follow-up Fee (৳)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _fuFeeController,
                            style: TextStyle(color: AppColors.textColor(context)),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '600',
                              hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                              prefixIcon: Icon(Icons.receipt_outlined, color: AppColors.textLightColor(context)),
                              fillColor: AppColors.inputFillColor(context),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text('Experience (Years)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _expController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 10',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.history_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Bio & Clinical Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _bioController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Brief clinical overview, specializations...',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
