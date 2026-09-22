import 'package:flutter/material.dart';

class ApiConfig {
  // Current active API base URL (can be switched at runtime on Login screen)
  static String baseUrl = 'http://192.168.42.129/mediq/backend/public/api/v1';

  static const String lanUrl = 'http://192.168.42.129/mediq/backend/public/api/v1';
  static const String emulatorUrl = 'http://10.0.2.2/mediq/backend/public/api/v1';
  static const String localhostUrl = 'http://localhost/mediq/backend/public/api/v1';
}

class AppDarkColors {
  static const Color background = Color(0xFF0B1120);
  static const Color card = Color(0xFF1E293B);
  static const Color cardElevated = Color(0xFF243248);
  static const Color text = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFF64748B);
  static const Color border = Color(0xFF334155);
  static const Color borderDark = Color(0xFF475569);
  static const Color inputFill = Color(0xFF162032);
  static const Color primaryLight = Color(0xFF1E2E4E);
  static const Color primaryBadge = Color(0xFF172554);
}

class AppColors {
  // Brand Royal Blue from mockup
  static const Color primary = Color(0xFF246BFD);
  static const Color primaryDark = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFFEFF4FF);
  static const Color primarySuperLight = Color(0xFFF5F8FF);
  
  static const Color doctorPrimary = Color(0xFF10B981);
  static const Color doctorPrimaryDark = Color(0xFF059669);

  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);

  static const Color background = Color(0xFFF9FAFB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFFE5E7EB);
  static const Color inputFill = Color(0xFFF9FAFB);

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color bg(BuildContext context) => isDark(context) ? AppDarkColors.background : background;
  static Color cardColor(BuildContext context) => isDark(context) ? AppDarkColors.card : card;
  static Color cardElevatedColor(BuildContext context) => isDark(context) ? AppDarkColors.cardElevated : card;
  static Color textColor(BuildContext context) => isDark(context) ? AppDarkColors.text : text;
  static Color textMutedColor(BuildContext context) => isDark(context) ? AppDarkColors.textMuted : textMuted;
  static Color textLightColor(BuildContext context) => isDark(context) ? AppDarkColors.textLight : textLight;
  static Color borderColor(BuildContext context) => isDark(context) ? AppDarkColors.border : border;
  static Color borderDarkColor(BuildContext context) => isDark(context) ? AppDarkColors.borderDark : borderDark;
  static Color inputFillColor(BuildContext context) => isDark(context) ? AppDarkColors.inputFill : inputFill;
  static Color primaryLightColor(BuildContext context) => isDark(context) ? AppDarkColors.primaryLight : primaryLight;
  static Color primaryBadgeColor(BuildContext context) => isDark(context) ? AppDarkColors.primaryBadge : primaryLight;
  static Color bottomBarColor(BuildContext context) => isDark(context) ? const Color(0xFF0B1120) : Colors.white;
  static Color dividerColor(BuildContext context) => isDark(context) ? AppDarkColors.border : border;
}
