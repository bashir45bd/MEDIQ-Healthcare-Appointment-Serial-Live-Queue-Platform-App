import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../state/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool showBorder;
  const ThemeToggleButton({Key? key, this.showBorder = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider();
    final isDark = themeProvider.isDark(context);

    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => themeProvider.toggleTheme(),
          onLongPress: () => ThemeSelectorDialog.show(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF4FF),
              shape: BoxShape.circle,
              border: showBorder
                  ? Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeSelectorDialog {
  static void show(BuildContext context) {
    final themeProvider = ThemeProvider();
    final current = themeProvider.themeMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? AppDarkColors.card : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Choose Appearance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppDarkColors.text : AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your preferred light or dark interface appearance.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              _buildOption(
                ctx,
                title: 'Light Mode',
                subtitle: 'Always use bright and crisp appearance',
                icon: Icons.light_mode_rounded,
                iconColor: const Color(0xFFF59E0B),
                isSelected: current == ThemeMode.light,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _buildOption(
                ctx,
                title: 'Dark Mode',
                subtitle: 'Easy on the eyes in low-light environments',
                icon: Icons.dark_mode_rounded,
                iconColor: const Color(0xFF818CF8),
                isSelected: current == ThemeMode.dark,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _buildOption(
                ctx,
                title: 'System Default',
                subtitle: 'Match your device system appearance setting',
                icon: Icons.settings_system_daydream_rounded,
                iconColor: const Color(0xFF10B981),
                isSelected: current == ThemeMode.system,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF4FF))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? AppDarkColors.text : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppDarkColors.textMuted : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
