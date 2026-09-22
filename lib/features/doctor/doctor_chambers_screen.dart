import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../state/auth_provider.dart';

class DoctorChambersScreen extends StatefulWidget {
  final AuthProvider auth;

  const DoctorChambersScreen({Key? key, required this.auth}) : super(key: key);

  @override
  State<DoctorChambersScreen> createState() => _DoctorChambersScreenState();
}

class _DoctorChambersScreenState extends State<DoctorChambersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _chambers = [];
  List<dynamic> _schedules = [];

  final List<String> _daysOfWeek = [
    'Sunday (রবিবার)',
    'Monday (সোমবার)',
    'Tuesday (মঙ্গলবার)',
    'Wednesday (বুধবার)',
    'Thursday (বৃহস্পতিবার)',
    'Friday (শুক্রবার)',
    'Saturday (শনিবার)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final chambersRes = await ApiService.get('/doctor/chambers');
      final schedulesRes = await ApiService.get('/doctor/schedules');
      if (mounted) {
        setState(() {
          _chambers = chambersRes is List ? chambersRes : [];
          _schedules = schedulesRes is List ? schedulesRes : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  String _getDayName(int dayNum) {
    if (dayNum >= 0 && dayNum < _daysOfWeek.length) {
      return _daysOfWeek[dayNum];
    }
    return 'Day $dayNum';
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final min = parts.length > 1 ? parts[1] : '00';
      final period = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$h12:$min $period';
    } catch (_) {
      return timeStr;
    }
  }

  // --------------------------------------------------------------------------
  // Chamber Modals
  // --------------------------------------------------------------------------
  void _openChamberSheet({dynamic existingChamber}) {
    final chamberMap = existingChamber is Map ? Map<String, dynamic>.from(existingChamber) : null;
    final isEdit = chamberMap != null;
    final nameCtrl = TextEditingController(text: chamberMap?['name']?.toString() ?? '');
    final addrCtrl = TextEditingController(text: (chamberMap?['address'] ?? chamberMap?['address_line'])?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: chamberMap?['contact_phone']?.toString() ?? '');
    final roomCtrl = TextEditingController(text: chamberMap?['room_number']?.toString() ?? '');
    final prefixCtrl = TextEditingController(text: chamberMap?['token_prefix']?.toString() ?? 'A');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDarkColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Chamber Details' : 'Add New Chamber',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(context),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textMutedColor(context)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildField(context, 'Chamber Name / Hospital', nameCtrl, 'e.g. Medinova Medical Center'),
                const SizedBox(height: 12),
                _buildField(context, 'Address / Location', addrCtrl, 'e.g. House 12, Road 5, Dhanmondi'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(context, 'Room / Floor', roomCtrl, 'e.g. Room 402'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(context, 'Token Prefix', prefixCtrl, 'e.g. A, B, C'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField(context, 'Contact Phone', phoneCtrl, 'e.g. 01711000000', keyboardType: TextInputType.phone),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chamber name is required.'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }
                          setSheetState(() => isSaving = true);
                          try {
                            final payload = {
                              'name': name,
                              'address_line': addrCtrl.text.trim(),
                              'contact_phone': phoneCtrl.text.trim(),
                              'room_number': roomCtrl.text.trim(),
                              'token_prefix': prefixCtrl.text.trim().toUpperCase(),
                              'city_id': 1,
                            };
                            if (isEdit) {
                              await ApiService.put('/doctor/chambers/${existingChamber['id']}', payload);
                            } else {
                              await ApiService.post('/doctor/chambers', payload);
                            }
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'Chamber updated successfully.' : 'Chamber added successfully.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _loadData();
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create Chamber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteChamber(dynamic id) async {
    final chamberId = int.tryParse(id?.toString() ?? '') ?? 0;
    if (chamberId == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardColor(context),
        title: Text('Delete Chamber?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
        content: Text('Are you sure you want to remove this chamber and its schedules?', style: TextStyle(color: AppColors.textMutedColor(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.delete('/doctor/chambers/$chamberId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamber removed.'), backgroundColor: AppColors.success),
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // Schedule Modals
  // --------------------------------------------------------------------------
  void _openScheduleSheet({dynamic preselectedChamberId}) {
    if (_chambers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one chamber before setting schedules.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    int selectedChamberId = int.tryParse(preselectedChamberId?.toString() ?? '') ??
        (int.tryParse(_chambers[0]['id']?.toString() ?? '') ?? 0);
    int selectedDay = 0; // 0 = Sunday
    TimeOfDay startTime = const TimeOfDay(hour: 16, minute: 0); // 4:00 PM
    TimeOfDay endTime = const TimeOfDay(hour: 20, minute: 0); // 8:00 PM
    final capacityCtrl = TextEditingController(text: '100');
    final durationCtrl = TextEditingController(text: '10');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDarkColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Configure Weekly Consultation Hours',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textMutedColor(context)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chamber Selector
                Text('Select Chamber', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputFillColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedChamberId,
                      isExpanded: true,
                      dropdownColor: AppColors.cardColor(context),
                      items: _chambers.map<DropdownMenuItem<int>>((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text('${c['name']} (${c['city_name'] ?? c['area_name'] ?? 'Chamber'})',
                              style: TextStyle(color: AppColors.textColor(context), fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedChamberId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Day of Week
                Text('Day of Week (সপ্তাহের দিন)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputFillColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedDay,
                      isExpanded: true,
                      dropdownColor: AppColors.cardColor(context),
                      items: List.generate(_daysOfWeek.length, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(_daysOfWeek[index], style: TextStyle(color: AppColors.textColor(context), fontSize: 14)),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedDay = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Time Pickers Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context))),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(context: ctx, initialTime: startTime);
                              if (picked != null) setSheetState(() => startTime = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.inputFillColor(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderColor(context)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(startTime.format(context), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
                                  const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                                ],
                              ),
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
                          Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context))),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(context: ctx, initialTime: endTime);
                              if (picked != null) setSheetState(() => endTime = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.inputFillColor(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderColor(context)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(endTime.format(context), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
                                  const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Capacity & Slot Duration
                Row(
                  children: [
                    Expanded(
                      child: _buildField(context, 'Max Patients ( ধারণক্ষমতা )', capacityCtrl, 'e.g. 100', keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(context, 'Slot Duration (Mins)', durationCtrl, 'e.g. 10', keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final cap = int.tryParse(capacityCtrl.text.trim()) ?? 100;
                          final dur = int.tryParse(durationCtrl.text.trim()) ?? 10;
                          final sTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                          final eTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                          setSheetState(() => isSaving = true);
                          try {
                            await ApiService.post('/doctor/schedules', {
                              'chamber_id': selectedChamberId,
                              'day_of_week': selectedDay,
                              'start_time': sTimeStr,
                              'end_time': eTimeStr,
                              'default_capacity': cap,
                              'slot_duration_minutes': dur,
                            });
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Weekly consultation schedule saved.'), backgroundColor: AppColors.success),
                            );
                            _loadData();
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Weekly Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(dynamic id) async {
    final scheduleId = int.tryParse(id?.toString() ?? '') ?? 0;
    if (scheduleId == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardColor(context),
        title: Text('Remove Schedule?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
        content: Text('Are you sure you want to remove this day consultation schedule?', style: TextStyle(color: AppColors.textMutedColor(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.delete('/doctor/schedules/$scheduleId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule removed.'), backgroundColor: AppColors.success),
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textColor(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMutedColor(context).withValues(alpha: 0.6), fontSize: 13),
            filled: true,
            fillColor: AppColors.inputFillColor(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.borderColor(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.borderColor(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Build Screen
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          'Chambers & Schedules',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textColor(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMutedColor(context),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Chambers (${_chambers.length})'),
            Tab(text: 'Weekly Hours (${_schedules.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChambersTab(),
                _buildSchedulesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openChamberSheet();
          } else {
            _openScheduleSheet();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Add Chamber' : 'Set Weekly Hours', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChambersTab() {
    if (_chambers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.meeting_room_outlined, size: 64, color: AppColors.textMutedColor(context)),
              const SizedBox(height: 16),
              Text('No Chambers Configured Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
              const SizedBox(height: 8),
              Text('Add your hospital, clinic or private practice chambers here so patients can book serials.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context))),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openChamberSheet(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Chamber'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: _chambers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final c = _chambers[index];
        final schedules = (c['schedules'] as List?) ?? [];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightColor(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c['name'] ?? 'Chamber',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Prefix: ${c['token_prefix'] ?? 'A'}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (c['address_line'] != null && c['address_line'].isNotEmpty)
                          Text(
                            c['address_line'],
                            style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context)),
                          ),
                        if (c['room_number'] != null && c['room_number'].isNotEmpty)
                          Text(
                            'Room: ${c['room_number']}',
                            style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                          ),
                        if (c['contact_phone'] != null && c['contact_phone'].isNotEmpty)
                          Text(
                            '📞 ${c['contact_phone']}',
                            style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.borderColor(context)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${schedules.length} Consultation Shift${schedules.length == 1 ? '' : 's'} Configured',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMutedColor(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openScheduleSheet(preselectedChamberId: c['id']),
                      icon: const Icon(Icons.add_alarm_rounded, size: 15),
                      label: const Text('Add Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openChamberSheet(existingChamber: c),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLightColor(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _deleteChamber(c['id']),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSchedulesTab() {
    if (_schedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 64, color: AppColors.textMutedColor(context)),
              const SizedBox(height: 16),
              Text('No Weekly Hours Set Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
              const SizedBox(height: 8),
              Text('Configure your consultation days, times (e.g. Sunday 4:00 PM – 8:00 PM), and maximum patient intake capacity (e.g. 100 serials).',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context))),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openScheduleSheet(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Configure Weekly Hours'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: _schedules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = _schedules[index];
        final dayNum = int.tryParse(s['day_of_week']?.toString() ?? '0') ?? 0;
        final dayName = _getDayName(dayNum);
        final startTime = _formatTime(s['start_time']);
        final endTime = _formatTime(s['end_time']);
        final capacity = s['default_capacity'] ?? 100;
        final slotMin = s['slot_duration_minutes'] ?? 10;
        final chamberName = s['chamber_name'] ?? 'Chamber';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderColor(context)),
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
                    dayName.split(' ')[0].substring(0, 3).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dayName,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Max $capacity Serials',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🕒 $startTime – $endTime ($slotMin mins/patient)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textColor(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🏥 $chamberName',
                      style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                onPressed: () => _deleteSchedule(s['id']),
                tooltip: 'Delete Schedule',
              ),
            ],
          ),
        );
      },
    );
  }
}
