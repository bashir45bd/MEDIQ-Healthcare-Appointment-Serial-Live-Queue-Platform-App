import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/constants.dart';
import '../state/auth_provider.dart';
import 'permission_service.dart';

class PhotoUploadHelper {
  static Future<void> showPhotoActionSheet({
    required BuildContext context,
    required AuthProvider auth,
    VoidCallback? onSuccess,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.borderDarkColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Change Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to update your profile photo',
                  style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context)),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  ),
                  title: Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textColor(context))),
                  subtitle: Text('Use camera to click a new picture', style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context))),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndUpload(context, auth, ImageSource.camera, onSuccess);
                  },
                ),
                Divider(height: 16, color: AppColors.dividerColor(context)),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  ),
                  title: Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textColor(context))),
                  subtitle: Text('Select a picture from your device', style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context))),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndUpload(context, auth, ImageSource.gallery, onSuccess);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _pickAndUpload(
    BuildContext context,
    AuthProvider auth,
    ImageSource source,
    VoidCallback? onSuccess,
  ) async {
    try {
      await PermissionService.requestPhotoPermissions();

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Uploading profile photo...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await auth.uploadProfilePhoto(base64String);

      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        onSuccess?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Failed to upload image. Please try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
