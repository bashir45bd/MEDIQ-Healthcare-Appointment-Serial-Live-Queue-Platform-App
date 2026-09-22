import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/constants.dart';
import '../../models/doctor_model.dart';
import '../../models/appointment_model.dart';
import '../../models/queue_model.dart';
import '../../services/api_service.dart';
import '../../services/photo_upload_helper.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../state/theme_provider.dart';

class PatientShell extends StatefulWidget {
  final AuthProvider auth;

  const PatientShell({Key? key, required this.auth}) : super(key: key);

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _PatientHomeTab(auth: widget.auth, onNavigate: _navigateToTab),
      _PatientDoctorsTab(onNavigate: _navigateToTab),
      _PatientAppointmentsTab(onNavigate: _navigateToTab),
      _PatientLiveQueueTab(onNavigate: _navigateToTab),
      _PatientProfileTab(auth: widget.auth),
    ];

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
        body: pages[_currentIndex],
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
              onTap: _navigateToTab,
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
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded),
                  activeIcon: Icon(Icons.search_rounded),
                  label: 'Doctors',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  activeIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Appointments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_time_outlined),
                  activeIcon: Icon(Icons.access_time_filled_rounded),
                  label: 'Live Queue',
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
// 1. Patient Home Tab (Matches Screen 5: Medica Home)
// ---------------------------------------------------------------------------
class _PatientHomeTab extends StatefulWidget {
  final AuthProvider auth;
  final Function(int) onNavigate;

  const _PatientHomeTab({Key? key, required this.auth, required this.onNavigate}) : super(key: key);

  @override
  State<_PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<_PatientHomeTab> {
  List<DoctorModel> _featuredDoctors = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _dbSpecialties = [];
  List<Map<String, dynamic>> _marketingBanners = [];
  int _currentBannerPage = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  IconData _iconForSpecialty(String name, String? slug) {
    final s = '${slug ?? ''} $name'.toLowerCase();
    if (s.contains('cardio') || s.contains('heart')) return Icons.favorite_rounded;
    if (s.contains('derm') || s.contains('skin')) return Icons.auto_awesome_rounded;
    if (s.contains('general') || s.contains('medicine')) return Icons.medical_services_rounded;
    if (s.contains('gynec') || s.contains('obs') || s.contains('women')) return Icons.pregnant_woman_rounded;
    if (s.contains('pedia') || s.contains('child')) return Icons.child_care_rounded;
    if (s.contains('ortho') || s.contains('bone')) return Icons.accessibility_new_rounded;
    if (s.contains('neuro') || s.contains('brain')) return Icons.psychology_rounded;
    if (s.contains('ophthal') || s.contains('eye')) return Icons.visibility_rounded;
    if (s.contains('dent')) return Icons.health_and_safety_rounded;
    if (s.contains('nutri')) return Icons.restaurant_rounded;
    return Icons.local_hospital_rounded;
  }

  List<Map<String, dynamic>> get _displayCategories {
    final List<Map<String, dynamic>> list = [];
    if (_dbSpecialties.isNotEmpty) {
      final top7 = _dbSpecialties.take(7).toList();
      for (final sp in top7) {
        final name = sp['name']?.toString() ?? 'Specialty';
        final slug = sp['slug']?.toString();
        list.add({
          'name': name,
          'icon': _iconForSpecialty(name, slug),
          'is_more': false,
        });
      }
    } else {
      list.addAll([
        {'name': 'Cardiology', 'icon': Icons.favorite_rounded, 'is_more': false},
        {'name': 'Dermatology', 'icon': Icons.auto_awesome_rounded, 'is_more': false},
        {'name': 'General Med', 'icon': Icons.medical_services_rounded, 'is_more': false},
        {'name': 'Gynecology', 'icon': Icons.pregnant_woman_rounded, 'is_more': false},
        {'name': 'Pediatrics', 'icon': Icons.child_care_rounded, 'is_more': false},
        {'name': 'Orthopedics', 'icon': Icons.accessibility_new_rounded, 'is_more': false},
        {'name': 'Neurology', 'icon': Icons.psychology_rounded, 'is_more': false},
      ]);
    }
    list.add({
      'name': 'More (আরো)',
      'icon': Icons.grid_view_rounded,
      'is_more': true,
    });
    return list;
  }

  void _showAllSpecialtiesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
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
              decoration: BoxDecoration(
                color: AppColors.borderDarkColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Doctor Specialties (সকল বিভাগ)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textMutedColor(context)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _dbSpecialties.isEmpty
                  ? const Center(child: Text('No specialties found'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _dbSpecialties.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final sp = _dbSpecialties[i];
                        final name = sp['name']?.toString() ?? '';
                        final slug = sp['slug']?.toString();
                        final icon = _iconForSpecialty(name, slug);
                        final isSelected = _selectedCategory == name;

                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCategory = name;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryLightColor(context) : AppColors.inputFillColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.borderColor(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.primaryLightColor(context),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: isSelected ? Colors.white : AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.primary : AppColors.textColor(context),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: isSelected ? AppColors.primary : AppColors.textMutedColor(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    try {
      final results = await Future.wait([
        ApiService.get('/doctors'),
        ApiService.get('/specialties'),
        ApiService.get('/banners'),
      ]);
      final docs = results[0];
      final specs = results[1];
      final banners = results[2];
      if (mounted) {
        setState(() {
          _featuredDoctors = (docs is List) ? docs.map((d) => DoctorModel.fromJson(d)).toList() : [];
          _dbSpecialties = (specs is List) ? specs.map((s) => Map<String, dynamic>.from(s as Map)).toList() : [];
          _marketingBanners = (banners is List) ? banners.map((b) => Map<String, dynamic>.from(b as Map)).toList() : [];
          _isLoading = false;
        });
        _setupBannerTimer();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupBannerTimer() {
    _bannerTimer?.cancel();
    if (_marketingBanners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!mounted || !_bannerController.hasClients) return;
        final nextPage = (_currentBannerPage + 1) % _marketingBanners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Widget _buildMarketingSlider() {
    if (_marketingBanners.isEmpty) {
      return Container(
        width: double.infinity,
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
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Smart Chamber Serial',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'No More Waiting in\nHospital Waiting Rooms!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.3),
            ),
            const SizedBox(height: 8),
            const Text(
              'Book your doctor serial and arrive just on time using live tracker.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => widget.onNavigate(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                'Find Doctors Now',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 178,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (idx) {
              setState(() => _currentBannerPage = idx);
            },
            itemCount: _marketingBanners.length,
            itemBuilder: (context, index) {
              final b = _marketingBanners[index];
              final title = b['title']?.toString() ?? 'Featured Doctor';
              final subtitle = b['subtitle']?.toString() ?? '';
              final badge = b['badge_text']?.toString() ?? 'Featured';
              final doctorAvatar = b['doctor_avatar']?.toString() ?? b['image_url']?.toString();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: index % 2 == 0
                        ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
                        : [const Color(0xFF065F46), const Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.2),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => widget.onNavigate(1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: index % 2 == 0 ? const Color(0xFF1E3A8A) : const Color(0xFF065F46),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: const Size(0, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text(
                              'সিরিয়াল নিন (Book)',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 78,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (doctorAvatar != null && doctorAvatar.isNotEmpty)
                          ? Image.network(
                              ApiService.resolveImageUrl(doctorAvatar),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.person_rounded, size: 44, color: Colors.white70),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.medical_services_rounded, size: 36, color: Colors.white70),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_marketingBanners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_marketingBanners.length, (idx) {
              final isCur = _currentBannerPage == idx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCur ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCur ? AppColors.primary : AppColors.borderColor(context),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  List<DoctorModel> get _filteredDoctors {
    if (_selectedCategory == 'All' || _selectedCategory.startsWith('More')) {
      return _featuredDoctors;
    }
    return _featuredDoctors.where((d) {
      return d.specialties.toLowerCase().contains(_selectedCategory.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.auth.currentUser?.fullName ?? 'Patient';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            AppAvatar(
              imageUrl: widget.auth.currentUser?.profilePhoto,
              name: userName,
              radius: 20,
              onTap: () => widget.onNavigate(4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Good Morning 👋',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMutedColor(context), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    userName,
                    style: TextStyle(fontSize: 15, color: AppColors.textColor(context), fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 4, right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              icon: Icon(Icons.notifications_none_rounded, color: AppColors.textColor(context), size: 20),
              onPressed: () {},
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 2, right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              icon: Icon(Icons.bookmark_outline_rounded, color: AppColors.textColor(context), size: 20),
              onPressed: () => widget.onNavigate(2),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // 1. Search Bar
                  GestureDetector(
                    onTap: () => widget.onNavigate(1),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inputFillColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderColor(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppColors.textLightColor(context), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search doctor, specialty...',
                              style: TextStyle(color: AppColors.textLightColor(context), fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Marketing Doctor Slider / Featured Banners (Admin controlled)
                  _buildMarketingSlider(),
                  const SizedBox(height: 24),

                  // 3. Doctor Speciality Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Doctor Speciality',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigate(1),
                        child: const Text(
                          'See All',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Speciality Circular Grid (Multiline, readable, and responsive)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _displayCategories.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, i) {
                      final item = _displayCategories[i];
                      final isMore = item['is_more'] == true;
                      final isSelected = !isMore && _selectedCategory == item['name'];
                      return GestureDetector(
                        onTap: () {
                          if (isMore) {
                            _showAllSpecialtiesSheet();
                          } else {
                            setState(() {
                              _selectedCategory = isSelected ? 'All' : item['name'];
                            });
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : (isMore ? AppColors.primaryLightColor(context) : AppColors.inputFillColor(context)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : (isMore ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: isSelected ? Colors.white : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 32,
                              child: Text(
                                item['name'],
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.textColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 5. Popular Doctors Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Doctors',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigate(1),
                        child: const Text(
                          'See All',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 6. Popular Doctors Cards
                  if (_filteredDoctors.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No doctors found in this specialty.',
                        style: TextStyle(color: AppColors.textMutedColor(context)),
                      ),
                    )
                  else
                    ..._filteredDoctors.map((doc) => _buildModernDoctorCard(doc)).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildModernDoctorCard(DoctorModel doc) {
    final chamberName = (doc.chambers.isNotEmpty)
        ? '${doc.chambers[0]['name']} (${doc.chambers[0]['city_name'] ?? ''})'
        : 'Chamber Available';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                imageUrl: doc.profilePhoto,
                name: doc.doctorName,
                radius: 32,
                fontSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            doc.doctorName,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                              const SizedBox(width: 3),
                              Text(
                                doc.ratingAvg > 0 ? doc.ratingAvg.toStringAsFixed(1) : '4.9',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc.specialties} • ${doc.designation}',
                      style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: AppColors.textLightColor(context), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            chamberName,
                            style: TextStyle(fontSize: 12, color: AppColors.textLightColor(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.borderColor(context)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consultation Fee', style: TextStyle(fontSize: 11, color: AppColors.textMutedColor(context))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '৳${doc.consultationFee.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _openDoctorBookingModal(context, doc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Book Serial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDoctorBookingModal(BuildContext context, DoctorModel doc) {
    if (doc.chambers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active chamber found for this doctor.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorBookingSheet(
        doc: doc,
        onBookingSuccess: () {
          widget.onNavigate(2); // Go to appointments tab
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Doctor Booking Sheet (Screens 6 & 7 & 11 & 12)
// ---------------------------------------------------------------------------
class _DoctorBookingSheet extends StatefulWidget {
  final DoctorModel doc;
  final VoidCallback onBookingSuccess;

  const _DoctorBookingSheet({Key? key, required this.doc, required this.onBookingSuccess}) : super(key: key);

  @override
  State<_DoctorBookingSheet> createState() => _DoctorBookingSheetState();
}

class _DoctorBookingSheetState extends State<_DoctorBookingSheet> {
  int _selectedDateIndex = 0;
  int _selectedChamberIndex = 0;
  String _patientType = 'NEW';
  bool _isSubmitting = false;

  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dates = List.generate(7, (i) => now.add(Duration(days: i)));
  }

  String _formatDayName(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
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

  @override
  Widget build(BuildContext context) {
    if (widget.doc.chambers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.borderDarkColor(context), borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.primaryLightColor(context), shape: BoxShape.circle),
              child: const Icon(Icons.meeting_room_outlined, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              widget.doc.doctorName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'This doctor has not configured an active chamber schedule yet. Please check back later or select another chamber doctor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    if (_selectedChamberIndex >= widget.doc.chambers.length) {
      _selectedChamberIndex = 0;
    }
    final chamber = widget.doc.chambers[_selectedChamberIndex];
    final selectedDt = _dates[_selectedDateIndex];
    final selectedDate = selectedDt.toIso8601String().split('T')[0];

    // Day of week: 0 = Sunday, 1 = Monday ... 6 = Saturday
    final dayOfWeek = (selectedDt.weekday == 7) ? 0 : selectedDt.weekday;
    final schedules = (chamber['schedules'] as List?) ?? [];
    final daySchedule = schedules.firstWhere(
      (s) => int.tryParse(s['day_of_week']?.toString() ?? '-1') == dayOfWeek,
      orElse: () => null,
    );

    final docFee = _patientType == 'NEW'
        ? widget.doc.consultationFee
        : (widget.doc.followUpFee > 0 ? widget.doc.followUpFee : widget.doc.consultationFee);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDarkColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
                children: [
                  // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Book Serial Appointment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textColor(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Doctor Info Snippet
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputFillColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: widget.doc.profilePhoto,
                        name: widget.doc.doctorName,
                        radius: 27,
                        fontSize: 18,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.doc.doctorName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                            ),
                            Text(
                              widget.doc.specialties,
                              style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context)),
                            ),
                            Text(
                              '${chamber['name']}',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Multi-Chamber Switcher (if doctor has multiple chambers)
                if (widget.doc.chambers.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Select Chamber (${widget.doc.chambers.length} Available)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.doc.chambers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = widget.doc.chambers[i];
                        final isSelected = _selectedChamberIndex == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedChamberIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.inputFillColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.borderColor(context),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.meeting_room_rounded,
                                  size: 16,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${c['name']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.textColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // 3 Quick Stats Blocks (Mockup Screen 6)
                Row(
                  children: [
                    _buildStatBlock(Icons.people_outline_rounded, '500+', 'Patients'),
                    const SizedBox(width: 10),
                    _buildStatBlock(Icons.verified_outlined, '${widget.doc.experienceYears > 0 ? widget.doc.experienceYears : 8}+ Yrs', 'Experience'),
                    const SizedBox(width: 10),
                    _buildStatBlock(Icons.star_border_rounded, widget.doc.ratingAvg > 0 ? widget.doc.ratingAvg.toStringAsFixed(1) : '4.9', 'Rating'),
                  ],
                ),
                const SizedBox(height: 24),

                // Select Date (Mockup Screen 7)
                Text(
                  'Select Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final dt = _dates[i];
                      final isSelected = _selectedDateIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDateIndex = i),
                        child: Container(
                          width: 65,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.cardColor(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.borderColor(context),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatDayName(dt),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white70 : AppColors.textMutedColor(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${dt.day}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : AppColors.textColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic Chamber Schedule & Queue Info
                Text(
                  'Chamber Schedule & Serial Queue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                ),
                const SizedBox(height: 12),
                if (daySchedule != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_formatDayName(selectedDt)} Shift: ${_formatTime(daySchedule['start_time'])} – ${_formatTime(daySchedule['end_time'])}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Max ${daySchedule['default_capacity'] ?? 100} Serials',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.2)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'First-Come, First-Served Token Queue. Booking gives you the next available serial number.',
                                style: TextStyle(fontSize: 12, color: AppColors.textColor(context), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_rounded, color: Color(0xFFB45309), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Session Scheduled for ${_formatDayName(selectedDt)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Doctor has no consultation hours on this day at this chamber. Please select another date or switch chamber above.',
                                style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Patient Type Toggle
                Text(
                  'Patient Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _patientType = 'NEW'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _patientType == 'NEW' ? AppColors.primary : AppColors.inputFillColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _patientType == 'NEW' ? AppColors.primary : AppColors.borderColor(context),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'New Patient',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _patientType == 'NEW' ? Colors.white : AppColors.textMutedColor(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _patientType = 'FOLLOWUP'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _patientType == 'FOLLOWUP' ? AppColors.primary : AppColors.inputFillColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _patientType == 'FOLLOWUP' ? AppColors.primary : AppColors.borderColor(context),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Follow-up Visit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _patientType == 'FOLLOWUP' ? Colors.white : AppColors.textMutedColor(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Payment Summary Breakdown (Mockup Screen 11)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.inputFillColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Doctor Fee (Pay at Chamber)', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Text('৳${docFee.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Serial Booking Service', style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Text('৳50.00', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Promo Offer (FIRSTFREE)', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          const Text('-৳50.00', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Divider(height: 20, color: AppColors.borderDarkColor(context)),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Payable Online Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textColor(context))),
                          ),
                          const SizedBox(width: 8),
                          const Text('৳0.00 (FREE)', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: (_isSubmitting || daySchedule == null)
                      ? null
                      : () => _confirmBooking(selectedDate, chamber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.inputFillColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          daySchedule == null
                              ? 'Chamber Closed on this Day'
                              : 'Confirm & Take Next Serial (টোকেন নিন)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: daySchedule == null ? AppColors.textMutedColor(context) : Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildStatBlock(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.inputFillColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textColor(context))),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(subtitle, style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBooking(String appointmentDate, dynamic chamber) async {
    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService.post('/appointments/book', {
        'doctor_id': widget.doc.id,
        'chamber_id': chamber['id'],
        'appointment_date': appointmentDate,
        'patient_type': _patientType,
        'promo_code': 'FIRSTFREE',
      });

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet

      // Show Success Modal Dialog (Mockup Screen 12)
      _showBookingSuccessDialog(res);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showBookingSuccessDialog(dynamic res) {
    final token = res['token_display'] ?? 'SERIAL';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLightColor(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                'Serial Token Issued!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Your doctor serial appointment is confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightColor(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text('YOUR SERIAL NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      token,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              if (res['expected_arrival_time'] != null || res['estimated_consultation_time'] != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      if (res['expected_arrival_time'] != null) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text('চেম্বারে আসার সময়:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                            ),
                            const SizedBox(width: 8),
                            Text(res['expected_arrival_time'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (res['estimated_consultation_time'] != null) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text('ডাক্তার দেখার সময় (আনুমানিক):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                            ),
                            const SizedBox(width: 8),
                            Text(res['estimated_consultation_time'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        (res['arrival_note'] ?? 'অনুগ্রহ করে ডাক্তার দেখার ২০-২৫ মিনিট আগে চেম্বারে পৌঁছান।').toString(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF047857), height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onBookingSuccess();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('View In Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Patient Doctors Tab (Search & Filter)
// ---------------------------------------------------------------------------
class _PatientDoctorsTab extends StatefulWidget {
  final Function(int) onNavigate;

  const _PatientDoctorsTab({Key? key, required this.onNavigate}) : super(key: key);

  @override
  State<_PatientDoctorsTab> createState() => _PatientDoctorsTabState();
}

class _PatientDoctorsTabState extends State<_PatientDoctorsTab> {
  final _searchController = TextEditingController();
  List<DoctorModel> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchDoctors();
  }

  Future<void> _searchDoctors([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/doctors?query=' + Uri.encodeComponent(query));
      if (mounted) {
        setState(() {
          _doctors = (res is List) ? res.map((d) => DoctorModel.fromJson(d)).toList() : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('Find Chamber Doctors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.textColor(context)),
              decoration: InputDecoration(
                hintText: 'Search doctor by name or specialty...',
                hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textLightColor(context)),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppColors.textLightColor(context)),
                  onPressed: () {
                    _searchController.clear();
                    _searchDoctors();
                  },
                ),
                fillColor: AppColors.inputFillColor(context),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderColor(context)),
                ),
              ),
              onSubmitted: (val) => _searchDoctors(val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _doctors.isEmpty
                    ? Center(child: Text('No doctors found.', style: TextStyle(color: AppColors.textMutedColor(context))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _doctors.length,
                        itemBuilder: (context, i) {
                          final doc = _doctors[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardColor(context),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.borderColor(context)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                AppAvatar(
                                  imageUrl: doc.profilePhoto,
                                  name: doc.doctorName,
                                  radius: 29,
                                  fontSize: 17,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(doc.doctorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 3),
                                      Text('${doc.specialties} • ${doc.designation}', style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('Fee: ৳${doc.consultationFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (doc.chambers.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('This doctor has not set up an active chamber schedule yet.'),
                                          backgroundColor: AppColors.warning,
                                        ),
                                      );
                                      return;
                                    }
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => _DoctorBookingSheet(
                                        doc: doc,
                                        onBookingSuccess: () => widget.onNavigate(2),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 0,
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Patient Appointments Tab (Mockup Screens 13, 14, 15)
// ---------------------------------------------------------------------------
class _PatientAppointmentsTab extends StatefulWidget {
  final Function(int) onNavigate;

  const _PatientAppointmentsTab({Key? key, required this.onNavigate}) : super(key: key);

  @override
  State<_PatientAppointmentsTab> createState() => _PatientAppointmentsTabState();
}

class _PatientAppointmentsTabState extends State<_PatientAppointmentsTab> {
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String _activeTab = 'Upcoming'; // 'Upcoming', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      final res = await ApiService.get('/appointments');
      if (mounted) {
        setState(() {
          _appointments = (res is List) ? res.map((a) => AppointmentModel.fromJson(a)).toList() : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AppointmentModel> get _filteredList {
    if (_activeTab == 'Upcoming') {
      return _appointments.where((a) => a.status == 'BOOKED' || a.status == 'CHECKED_IN' || a.status == 'IN_CONSULTATION').toList();
    } else if (_activeTab == 'Completed') {
      return _appointments.where((a) => a.status == 'COMPLETED').toList();
    } else {
      return _appointments.where((a) => a.status == 'CANCELLED' || a.status == 'NO_SHOW').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('My Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Sub-tabs switcher (Upcoming | Completed | Cancelled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.inputFillColor(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Row(
                children: [
                  _buildSubTab('Upcoming'),
                  _buildSubTab('Completed'),
                  _buildSubTab('Cancelled'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAppointments,
                    child: _filteredList.isEmpty
                        ? Center(
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
                                const SizedBox(height: 14),
                                Text(
                                  'No $_activeTab Appointments',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textColor(context)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Appointments in this category will appear here.',
                                  style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _filteredList.length,
                            itemBuilder: (context, i) {
                              final a = _filteredList[i];
                              return _buildAppointmentCard(a);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(String tab) {
    final isSelected = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMutedColor(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = (a.status == 'BOOKED' || a.status == 'CHECKED_IN' || a.status == 'IN_CONSULTATION');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive ? AppColors.primary.withValues(alpha: 0.25) : AppColors.borderColor(context),
          width: isActive ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? AppColors.primary.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Token Pill + Modern Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
              border: Border(bottom: BorderSide(color: AppColors.borderColor(context), width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'SERIAL ${a.tokenDisplay}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(a.status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryLightColor(context),
                      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.doctorName ?? 'Doctor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLightColor(context)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${a.chamberName ?? 'Chamber'} • ${a.appointmentDate}',
                                  style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Timing Highlight Dual Cards (Arrival Time & Estimated Consultation Time)
                Row(
                  children: [
                    // Arrival Time Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.directions_walk_rounded, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'চেম্বারে আসার সময়',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                a.expectedArrivalTime ?? '২০-২৫ মি. আগে',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Consultation Time Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'ডাক্তার দেখার সময়',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                a.estimatedConsultationTime ?? 'সিরিয়ালে আছেন',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Action Buttons: Direct Live Queue Tracking (No manual check-in required)
                if (isActive) ...[
                  InkWell(
                    onTap: () => widget.onNavigate(3),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF0369A1)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'লাইভ সিরিয়াল ট্র্যাক করুন (Live Queue)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'স্ট্যাটাস: ${a.status}',
                          style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => widget.onNavigate(1),
                        icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.primary),
                        label: const Text('পুনরায় সিরিয়াল নিন', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg = AppColors.primaryLightColor(context);
    Color fg = AppColors.primary;
    String label = status;

    if (status == 'BOOKED') {
      bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
      fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      label = '● বুকড (সিরিয়ালে)';
    } else if (status == 'CHECKED_IN') {
      bg = isDark ? const Color(0xFF451A03).withValues(alpha: 0.3) : const Color(0xFFFEF3C7);
      fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      label = '● চেম্বারে উপস্থিত';
    } else if (status == 'IN_CONSULTATION') {
      bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : AppColors.successLight;
      fg = isDark ? const Color(0xFF34D399) : AppColors.success;
      label = '● ডাক্তারের সাথে আছেন';
    } else if (status == 'COMPLETED') {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      fg = AppColors.textMutedColor(context);
      label = '✓ সম্পন্ন';
    } else if (status == 'CANCELLED') {
      bg = isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : AppColors.dangerLight;
      fg = isDark ? const Color(0xFFF87171) : AppColors.danger;
      label = '✕ বাতিল';
    } else if (status == 'NO_SHOW') {
      bg = isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : AppColors.dangerLight;
      fg = isDark ? const Color(0xFFF87171) : AppColors.danger;
      label = 'উপস্থিত হননি';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Patient Live Queue Tab (Screens 8, 9, 10: Serial Tracker)
// ---------------------------------------------------------------------------
class _PatientLiveQueueTab extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const _PatientLiveQueueTab({Key? key, this.onNavigate}) : super(key: key);

  @override
  State<_PatientLiveQueueTab> createState() => _PatientLiveQueueTabState();
}

class _PatientLiveQueueTabState extends State<_PatientLiveQueueTab> {
  List<Map<String, dynamic>> _userAppointments = [];
  int? _selectedAppointmentId;
  QueueLiveModel? _queueData;
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadLiveQueue();
    // Auto-refresh every 25 seconds while active on this tab
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && _selectedAppointmentId != null) {
        _loadLiveQueue(selectAptId: _selectedAppointmentId, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  String _formatAppointmentDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      final daysBn = ['রবিবার', 'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার'];
      final dow = (dt.weekday == 7) ? 0 : dt.weekday;
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${days[dow]} (${daysBn[dow]})';
    } catch (_) {
      return dateStr;
    }
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

  Future<void> _loadLiveQueue({int? selectAptId, bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final apts = await ApiService.get('/appointments');
      if (apts is List && apts.isNotEmpty) {
        final aptList = apts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Filter active appointments
        final activeList = aptList.where((a) =>
            ['CONSULTING', 'CALLED', 'CHECKED_IN', 'WAITING', 'BOOKED'].contains(a['status'])
        ).toList();

        // Sort: Today's active appointments first (by token), then future dates ASC, then past
        activeList.sort((a, b) {
          final aDate = a['appointment_date']?.toString() ?? '';
          final bDate = b['appointment_date']?.toString() ?? '';
          final aIsToday = (aDate == todayStr);
          final bIsToday = (bDate == todayStr);

          if (aIsToday && !bIsToday) return -1;
          if (!aIsToday && bIsToday) return 1;

          final dateComp = aDate.compareTo(bDate);
          if (dateComp != 0) return dateComp;

          final aTok = int.tryParse(a['token_number']?.toString() ?? '') ?? 0;
          final bTok = int.tryParse(b['token_number']?.toString() ?? '') ?? 0;
          return aTok.compareTo(bTok);
        });

        _userAppointments = activeList.isNotEmpty ? activeList : aptList;

        int targetId;
        if (selectAptId != null && _userAppointments.any((a) => a['id'] == selectAptId)) {
          targetId = selectAptId;
        } else if (_selectedAppointmentId != null && _userAppointments.any((a) => a['id'] == _selectedAppointmentId)) {
          targetId = _selectedAppointmentId!;
        } else {
          targetId = _userAppointments.first['id'];
        }

        _selectedAppointmentId = targetId;

        final q = await ApiService.get('/queue/live/$targetId');
        if (mounted) {
          setState(() {
            _queueData = QueueLiveModel.fromJson(q);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userAppointments = [];
            _selectedAppointmentId = null;
            _queueData = null;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          'Live Serial Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh Queue',
            onPressed: () => _loadLiveQueue(selectAptId: _selectedAppointmentId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _queueData == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadLiveQueue(selectAptId: _selectedAppointmentId),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 1. Multiple Appointment Switcher (If patient has >1 appointment)
                      if (_userAppointments.length > 1) ...[
                        _buildAppointmentSwitcher(),
                        const SizedBox(height: 14),
                      ],

                      // 2. Main Content based on whether appointment is for FUTURE or TODAY
                      if (_queueData!.isFuture)
                        _buildFutureAppointmentView()
                      else
                        _buildTodayLiveQueueView(),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLightColor(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'কোনো সক্রিয় সিরিয়াল নেই',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context)),
            ),
            const SizedBox(height: 4),
            Text(
              'No Active Serial Queue',
              style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'ডাক্তারের চেম্বার সিরিয়াল নিলে এখানে লাইভ সিরিয়াল অবস্থান, ডাক্তারের রোগী দেখার রিয়েল-টাইম স্ট্যাটাস ও অপেক্ষার সময় দেখতে পাবেন।',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate?.call(1),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('ডাক্তার খুঁজুন ও সিরিয়াল নিন (Find Doctors)', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Appointment Switcher Chips (When user has multiple bookings)
  // ---------------------------------------------------------------------------
  Widget _buildAppointmentSwitcher() {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'আপনার বুক করা সিরিয়ালসমূহ (${_userAppointments.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMutedColor(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'সুইচ করতে ট্যাপ করুন',
              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _userAppointments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final apt = _userAppointments[idx];
              final aptId = apt['id'];
              final isSelected = (aptId == _selectedAppointmentId);
              final aDate = apt['appointment_date']?.toString() ?? '';
              final isToday = (aDate == todayStr);
              final docName = apt['doctor_name']?.toString() ?? 'Doctor';
              final token = apt['token_display']?.toString() ?? '--';

              final label = isToday ? '🟢 আজ • $token' : '🗓️ $aDate • $token';

              return GestureDetector(
                onTap: () {
                  if (_selectedAppointmentId != aptId) {
                    _loadLiveQueue(selectAptId: aptId);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.cardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderColor(context),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textColor(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($docName)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white70 : AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // View for FUTURE Scheduled Appointment
  // ---------------------------------------------------------------------------
  Widget _buildFutureAppointmentView() {
    final dateDisplay = _queueData!.appointmentDateFormatted.isNotEmpty
        ? _queueData!.appointmentDateFormatted
        : _formatAppointmentDate(_queueData!.appointmentDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Indigo Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3730A3).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'আসন্ন অ্যাপয়েন্টমেন্ট (UPCOMING)',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'অপেক্ষমান / Scheduled',
                      style: TextStyle(color: Color(0xFF3730A3), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'আপনার বুক করা সিরিয়াল নম্বর (YOUR SERIAL TOKEN)',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _queueData!.yourToken,
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateDisplay,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              if (_queueData!.chamberStartTime != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'চেম্বার শিফট: ${_formatTime(_queueData!.chamberStartTime)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.local_hospital_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dr. ${_queueData!.doctorName} • ${_queueData!.chamberName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info Notice Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLightColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'লাইভ সিরিয়াল ট্র্যাকার বার্তা',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textColor(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'এই সিরিয়ালটি ভবিষ্যতের নির্ধারিত চেম্বার তারিখের জন্য। চেম্বারের দিন এই স্ক্রিনে আসলে আপনি লাইভ দেখতে পাবেন ডাক্তার চেম্বারে রোগী দেখছেন কিনা, চলমান রোগী কে, আপনার ডাক কখন আসছে এবং আনুমানিক অপেক্ষা সময়।',
                style: TextStyle(fontSize: 12.5, color: AppColors.textColor(context), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => widget.onNavigate?.call(2),
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: const Text('সকল অ্যাপয়েন্টমেন্ট দেখুন (View Appointments)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // View for TODAY Active Live Queue
  // ---------------------------------------------------------------------------
  Widget _buildTodayLiveQueueView() {
    final isConsulting = _queueData!.isDoctorConsulting;
    final isBreak = (_queueData!.isBreak || _queueData!.doctorStatus == 'SHORT_BREAK' || _queueData!.doctorStatus == 'PAUSED');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Doctor Presence & Booking Status Banner
        _buildPresenceBanner(),

        // 1. Session Status Banner (Consulting / Break / Ready)
        if (isBreak)
          _buildBreakBanner()
        else if (isConsulting)
          _buildConsultingBanner()
        else
          _buildReadyBanner(),

        const SizedBox(height: 12),

        // 2. ⭐ CORE FEATURE: ONGOING vs NEXT DUAL PANEL
        _buildOngoingNextDualPanel(),

        const SizedBox(height: 12),

        // 3. ⭐ YOUR TURN NOTIFICATION BANNER
        _buildYourTurnBanner(),

        const SizedBox(height: 14),

        // 4. ⭐ YOUR SERIAL TOKEN HERO CARD
        _buildYourTokenHeroCard(),

        const SizedBox(height: 16),

        // 5. ⭐ LIVE QUEUE ROSTER (TODAY'S LINEUP)
        if (_queueData!.queueRoster.isNotEmpty)
          _buildLiveQueueRoster(),

        const SizedBox(height: 14),

        // 6. Auto-Update Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLightColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'চেম্বারে রোগী দেখা সম্পন্ন হলে লাইভ সিরিয়াল এবং অপেক্ষার সময় স্বয়ংক্রিয়ভাবে আপডেট হয়।',
                  style: TextStyle(
                    color: AppColors.isDark(context) ? const Color(0xFF93C5FD) : AppColors.primaryDark,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Doctor Presence & Booking Status Banner
  // ---------------------------------------------------------------------------
  Widget _buildPresenceBanner() {
    final presence = _queueData!.presenceStatus;
    final isBookingOpen = _queueData!.isBookingOpen;
    if (presence == null && isBookingOpen) return const SizedBox.shrink();

    String presenceText = '👨‍⚕️ ডাক্তার চেম্বারে উপস্থিত আছেন (In Chamber)';
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF065F46);
    Color border = const Color(0xFF10B981);

    if (presence == 'PRAYER_BREAK') {
      presenceText = '🕌 ডাক্তার নামাজের বিরতিতে আছেন (Prayer Break)';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      border = const Color(0xFFF59E0B);
    } else if (presence == 'MEAL_BREAK') {
      presenceText = '🍽️ ডাক্তার খাবারের বিরতিতে আছেন (Meal Break)';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      border = const Color(0xFFF59E0B);
    } else if (presence == 'SHORT_PAUSE') {
      presenceText = '⏸️ ডাক্তার সাময়িক বিরতিতে আছেন (Short Pause)';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      border = const Color(0xFFF59E0B);
    } else if (presence == 'AWAY') {
      presenceText = '🚪 ডাক্তার চেম্বারের বাইরে আছেন (Doctor Outside)';
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      border = const Color(0xFFEF4444);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  presenceText,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: fg),
                ),
              ),
              if (!isBookingOpen) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'সিরিয়াল বন্ধ',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Doctor Consulting Live Banner
  // ---------------------------------------------------------------------------
  Widget _buildConsultingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🟢 ডাক্তার চেম্বারে রোগী দেখছেন',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                ),
                Text(
                  'Doctor is consulting patients in chamber right now',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('LIVE 🟢', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Doctor Break Banner
  // ---------------------------------------------------------------------------
  Widget _buildBreakBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Row(
        children: [
          Text(
            (_queueData!.statusNote?.contains('Prayer') ?? false)
                ? '🕌'
                : ((_queueData!.statusNote?.contains('Meal') ?? false) ? '🍽️' : '⏸️'),
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _queueData!.statusNote ?? 'ডাক্তার সাময়িক বিরতিতে আছেন (Doctor on Break)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF92400E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'বিরতি শেষ হলে সিরিয়াল পুনরায় চালু হবে। চেম্বারেই অপেক্ষা করুন।',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ready to Start Banner
  // ---------------------------------------------------------------------------
  Widget _buildReadyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLightColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'চেম্বার শুরু হওয়ার অপেক্ষায় (Session Ready to Start)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ⭐ Dual Panel: ONGOING & NEXT IN LINE
  // ---------------------------------------------------------------------------
  Widget _buildOngoingNextDualPanel() {
    final ongoing = _queueData!.ongoingPatient;
    final next = _queueData!.nextPatient;

    return Row(
      children: [
        // Left: ONGOING Patient
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('🟢 চলমান (Ongoing)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (ongoing != null && (ongoing['duration_minutes'] ?? 0) > 0)
                      Text(
                        '${ongoing['duration_minutes']} min',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ongoing?['token']?.toString() ?? 'None',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ongoing != null
                      ? (ongoing['is_you'] == true ? '⭐️ আপনার ভিজিট চলছে' : 'রুমে রোগী আছেন')
                      : 'ডাক্তার প্রস্তুত',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Right: NEXT Patient
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _queueData!.isYouNext ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _queueData!.isYouNext ? const Color(0xFFF59E0B) : AppColors.borderColor(context),
                width: _queueData!.isYouNext ? 2 : 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _queueData!.isYouNext ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _queueData!.isYouNext ? '⭐ YOU ARE NEXT' : '⏳ পরবর্তী (Next)',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    next?['token']?.toString() ?? 'None',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _queueData!.isYouNext ? const Color(0xFF92400E) : AppColors.textColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next != null
                      ? (next['is_you'] == true ? '🔔 প্রস্তুত থাকুন' : 'পরবর্তী সিরিয়াল')
                      : 'লাইনে কেউ নেই',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _queueData!.isYouNext ? const Color(0xFFB45309) : AppColors.textMutedColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ⭐ Your Turn Notification Banner
  // ---------------------------------------------------------------------------
  Widget _buildYourTurnBanner() {
    if (_queueData!.isYouOngoing) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.door_front_door_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 আপনার সিরিয়াল চলছে! সরাসরি ডাক্তারের রুমে প্রবেশ করুন।',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_queueData!.isYouNext) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🔔 আপনি পরবর্তী রোগী! চেম্বারের দরজার সামনে প্রস্তুত থাকুন।',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_queueData!.patientsAhead > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLightColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'আপনার সিরিয়ালের আগে ${_queueData!.patientsAhead} জন রোগী আছেন • আনুমানিক অপেক্ষা: ${_queueData!.estimatedWait}',
                style: TextStyle(
                  color: AppColors.isDark(context) ? const Color(0xFF93C5FD) : AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // ⭐ Your Token Hero Card (Responsive, no overflow)
  // ---------------------------------------------------------------------------
  Widget _buildYourTokenHeroCard() {
    final dateDisplay = _queueData!.appointmentDateFormatted.isNotEmpty
        ? _queueData!.appointmentDateFormatted
        : _formatAppointmentDate(_queueData!.appointmentDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF246BFD), Color(0xFF1952C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'YOUR CHAMBER SERIAL',
                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              if (_queueData!.lastUpdated.isNotEmpty)
                Text(
                  'Live: ${_queueData!.lastUpdated}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'আপনার সিরিয়াল নম্বর (YOUR TOKEN)',
            style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _queueData!.yourToken,
              style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dr. ${_queueData!.doctorName} • ${_queueData!.chamberName}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            dateDisplay,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),

          // 3-Metric Responsive Row
          Row(
            children: [
              Expanded(
                child: _buildHeroSubMetric(
                  'আগে আছেন',
                  '${_queueData!.patientsAhead} জন',
                  Icons.people_outline_rounded,
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
              Expanded(
                child: _buildHeroSubMetric(
                  'অপেক্ষার সময়',
                  _queueData!.estimatedWait,
                  Icons.timer_outlined,
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
              Expanded(
                child: _buildHeroSubMetric(
                  'আসার সময়',
                  _queueData!.recommendedArrival,
                  Icons.directions_walk_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubMetric(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ⭐ Live Queue Roster (Horizontal line of tokens today)
  // ---------------------------------------------------------------------------
  Widget _buildLiveQueueRoster() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Live Queue Line (সিরিয়াল ক্রম)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textColor(context)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightColor(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_queueData!.queueRoster.length} Patients',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _queueData!.queueRoster.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final r = _queueData!.queueRoster[idx];
                final isYou = (r['is_you'] == 1 || r['is_you'] == true);
                final isOngoing = (r['is_ongoing'] == 1 || r['is_ongoing'] == true);
                final isNext = (r['is_next'] == 1 || r['is_next'] == true);
                final rToken = r['token_display']?.toString() ?? 'Token';
                final rStatus = r['status']?.toString() ?? 'WAITING';

                Color borderCol = AppColors.borderColor(context);
                Color bgCol = AppColors.inputFillColor(context);
                String tagLabel = 'অপেক্ষমান';
                Color tagBg = AppColors.borderColor(context);
                Color tagText = AppColors.textMutedColor(context);

                if (isOngoing) {
                  borderCol = const Color(0xFF10B981);
                  bgCol = const Color(0xFFECFDF5);
                  tagLabel = '🟢 চলমান';
                  tagBg = const Color(0xFF10B981);
                  tagText = Colors.white;
                } else if (isNext) {
                  borderCol = const Color(0xFFF59E0B);
                  bgCol = const Color(0xFFFEF3C7);
                  tagLabel = '⏳ পরবর্তী';
                  tagBg = const Color(0xFFF59E0B);
                  tagText = Colors.white;
                } else if (isYou) {
                  borderCol = AppColors.primary;
                  bgCol = AppColors.primaryLightColor(context);
                  tagLabel = '⭐️ আপনি';
                  tagBg = AppColors.primary;
                  tagText = Colors.white;
                } else if (rStatus == 'CHECKED_IN') {
                  tagLabel = 'উপস্থিত';
                }

                return Container(
                  width: 90,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: bgCol,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: (isYou || isOngoing || isNext) ? 1.5 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          rToken,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: (isOngoing)
                                ? const Color(0xFF065F46)
                                : ((isNext) ? const Color(0xFF92400E) : (isYou ? AppColors.primary : AppColors.textColor(context))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          tagLabel,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagText),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Patient Profile Tab & Centered Logout Confirmation (Mockup Screen 18 & 19)
// ---------------------------------------------------------------------------
class _PatientProfileTab extends StatelessWidget {
  final AuthProvider auth;

  const _PatientProfileTab({Key? key, required this.auth}) : super(key: key);

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
                'Are you sure you want to sign out from MEDIQ? You can sign back in at any time.',
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
    final fullName = user?.fullName ?? 'Patient User';
    final phone = user?.phone ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
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
          // Profile Avatar & Information (Mockup Screen 18)
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
                  fullName,
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
                    'Patient Account',
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
          _buildMenuTile(context, Icons.person_outline_rounded, 'Edit Profile', () => _showEditProfileModal(context)),
          _buildMenuTile(context, Icons.camera_alt_outlined, 'Change Profile Photo', () => PhotoUploadHelper.showPhotoActionSheet(context: context, auth: auth)),
          _buildMenuTile(context, Icons.notifications_none_rounded, 'Notification Settings', () {}),
          _buildMenuTile(context, Icons.receipt_long_rounded, 'Medical Records & Prescriptions', () {}),
          _buildMenuTile(context, Icons.history_rounded, 'Chamber Serial History', () {}),
          _buildMenuTile(context, Icons.help_outline_rounded, 'Help Center / Support', () {}),
          _buildMenuTile(context, Icons.privacy_tip_outlined, 'Privacy Policy', () {}),
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

  void _showEditProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PatientEditProfileSheet(auth: auth),
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
// 7. Patient Edit Profile Sheet Modal
// ---------------------------------------------------------------------------
class _PatientEditProfileSheet extends StatefulWidget {
  final AuthProvider auth;

  const _PatientEditProfileSheet({Key? key, required this.auth}) : super(key: key);

  @override
  State<_PatientEditProfileSheet> createState() => _PatientEditProfileSheetState();
}

class _PatientEditProfileSheetState extends State<_PatientEditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _dobController;
  late final TextEditingController _ecNameController;
  late final TextEditingController _ecPhoneController;
  String _gender = 'MALE';
  String _bloodGroup = 'O+';
  bool _isSaving = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _genders = ['MALE', 'FEMALE', 'OTHER'];

  @override
  void initState() {
    super.initState();
    final user = widget.auth.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _addressController = TextEditingController();
    _dobController = TextEditingController();
    _ecNameController = TextEditingController();
    _ecPhoneController = TextEditingController();
    _loadProfileDetails();
  }

  Future<void> _loadProfileDetails() async {
    try {
      final res = await ApiService.get('/patients/profile');
      if (res != null && mounted) {
        setState(() {
          if (res['gender'] != null) _gender = res['gender'];
          if (res['blood_group'] != null) _bloodGroup = res['blood_group'];
          if (res['dob'] != null) _dobController.text = res['dob'];
          if (res['address'] != null) _addressController.text = res['address'];
          if (res['emergency_contact_name'] != null) _ecNameController.text = res['emergency_contact_name'];
          if (res['emergency_contact_phone'] != null) _ecPhoneController.text = res['emergency_contact_phone'];
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'full_name': name,
        'email': _emailController.text.trim(),
        'gender': _gender,
        'blood_group': _bloodGroup,
        'dob': _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'emergency_contact_name': _ecNameController.text.trim().isNotEmpty ? _ecNameController.text.trim() : null,
        'emergency_contact_phone': _ecPhoneController.text.trim().isNotEmpty ? _ecPhoneController.text.trim() : null,
      };

      await ApiService.put('/patients/profile', payload);
      await widget.auth.updateUserInfo(
        fullName: name,
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
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
    _addressController.dispose();
    _dobController.dispose();
    _ecNameController.dispose();
    _ecPhoneController.dispose();
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
                    Text('Edit Profile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textColor(context))),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textColor(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Full Name
                Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Your Full Name',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Email
                Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'patient@example.com',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Blood Group & Gender Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Blood Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.inputFillColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderColor(context)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _bloodGroup,
                                isExpanded: true,
                                dropdownColor: AppColors.cardColor(context),
                                style: TextStyle(color: AppColors.textColor(context), fontSize: 14),
                                items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg, style: TextStyle(color: AppColors.textColor(context))))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _bloodGroup = val);
                                },
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
                          Text('Gender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.inputFillColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderColor(context)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _gender,
                                isExpanded: true,
                                dropdownColor: AppColors.cardColor(context),
                                style: TextStyle(color: AppColors.textColor(context), fontSize: 14),
                                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: AppColors.textColor(context))))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _gender = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date of Birth
                Text('Date of Birth (YYYY-MM-DD)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _dobController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  decoration: InputDecoration(
                    hintText: 'e.g. 1995-08-15',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Address
                Text('Residential Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _addressController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  decoration: InputDecoration(
                    hintText: 'House, Road, Area, City',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.home_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Emergency Contact Name
                Text('Emergency Contact Person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _ecNameController,
                  style: TextStyle(color: AppColors.textColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Contact Person Name',
                    hintStyle: TextStyle(color: AppColors.textLightColor(context)),
                    prefixIcon: Icon(Icons.contact_phone_outlined, color: AppColors.textLightColor(context)),
                    fillColor: AppColors.inputFillColor(context),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.borderColor(context))),
                  ),
                ),
                const SizedBox(height: 14),

                // Emergency Phone
                Text('Emergency Contact Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textColor(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _ecPhoneController,
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
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
