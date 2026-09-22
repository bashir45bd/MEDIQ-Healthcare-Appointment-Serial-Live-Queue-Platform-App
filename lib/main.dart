import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'routing/app_router.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.initialize();
    AnalyticsService.initialize();
  } catch (e) {
    debugPrint('[FIREBASE BOOT ERROR] $e');
  }
  ConnectivityService.instance.initialize();
  runApp(const MediqApp());
}

class MediqApp extends StatefulWidget {
  const MediqApp({Key? key}) : super(key: key);

  @override
  State<MediqApp> createState() => _MediqAppState();
}

class _MediqAppState extends State<MediqApp> {
  final AuthProvider _authProvider = AuthProvider();
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _authProvider.addListener(() {
      if (mounted) setState(() {});
    });
    _themeProvider.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEDIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeProvider.themeMode,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: mediaQueryData.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: _ConnectivityOverlay(child: child ?? const SizedBox()),
        );
      },
      home: AppRouter(auth: _authProvider),
    );
  }
}

class _ConnectivityOverlay extends StatelessWidget {
  final Widget child;
  const _ConnectivityOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ConnectivityService.instance.justReconnected,
          builder: (context, justReconnected, _) {
            return Stack(
              children: [
                child,
                if (!isOnline)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ইন্টারনেট সংযোগ নেই',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'অনুগ্রহ করে আপনার নেটওয়ার্ক কানেকশন চেক করুন',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => ConnectivityService.instance.checkConnectionNow(),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'চেষ্টা করুন',
                                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else if (justReconnected)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '✅ ইন্টারনেট সংযোগ ফিরে এসেছে',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
