import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request notification permission on app startup or when booking
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Request photo gallery & camera permissions for profile picture upload
  static Future<bool> requestPhotoPermissions() async {
    try {
      if (kIsWeb) return true;

      if (Platform.isAndroid) {
        final photosStatus = await Permission.photos.request();
        final storageStatus = await Permission.storage.request();
        final cameraStatus = await Permission.camera.request();

        return photosStatus.isGranted || storageStatus.isGranted || cameraStatus.isGranted;
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.request();
        final camera = await Permission.camera.request();
        return photos.isGranted || camera.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting photo/camera permission: $e');
      return true;
    }
  }

  /// Request all essential initial permissions gracefully
  static Future<void> requestInitialAppPermissions() async {
    try {
      await requestNotificationPermission();
    } catch (e) {
      debugPrint('Error during initial permission request: $e');
    }
  }
}
