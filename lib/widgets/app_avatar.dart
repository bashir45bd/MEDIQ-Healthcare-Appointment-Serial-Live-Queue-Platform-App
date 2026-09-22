import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/api_service.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.primaryLight;
    final effectiveTextColor = textColor ?? AppColors.primary;
    final effectiveFontSize = fontSize ?? (radius * 0.72);

    String initials = 'M';
    final cleanName = name.replaceAll('Dr. ', '').trim();
    if (cleanName.isNotEmpty) {
      final parts = cleanName.split(' ');
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = cleanName.substring(0, cleanName.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final fullUrl = ApiService.resolveImageUrl(imageUrl);

    Widget avatarWidget;
    if (fullUrl.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: effectiveBg,
        child: ClipOval(
          child: Image.network(
            fullUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) {
              return Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: effectiveTextColor,
                    fontSize: effectiveFontSize,
                  ),
                ),
              );
            },
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: radius,
                  height: radius,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: effectiveBg,
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: effectiveTextColor,
            fontSize: effectiveFontSize,
          ),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }
    return avatarWidget;
  }
}
