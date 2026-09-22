import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _pendingApproval = false;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get pendingApproval => _pendingApproval;

  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataStr = prefs.getString('user_data');

      if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
        ApiService.authToken = token;
        final userMap = jsonDecode(userDataStr) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(userMap);
        NotificationService.syncTokenWithBackend();
      }
    } catch (e) {
      debugPrint('Error restoring cached session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/login', {
        'phone': phone,
        'password': password,
      });

      final token = res['token'];
      ApiService.authToken = token;

      final userMap = res['user'];
      _currentUser = UserModel.fromJson(userMap);

      try {
        final prefs = await SharedPreferences.getInstance();
        if (token != null) {
          await prefs.setString('auth_token', token.toString());
        }
        if (userMap != null) {
          await prefs.setString('user_data', jsonEncode(userMap));
        }
      } catch (e) {
        debugPrint('Error caching session: $e');
      }

      // Sync FCM Device Token & Log Analytics
      NotificationService.syncTokenWithBackend();
      AnalyticsService.logLogin(role: _currentUser?.role ?? 'PATIENT');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    _pendingApproval = false;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/register', data);

      if (res != null && res['pending_approval'] == true) {
        _isLoading = false;
        _pendingApproval = true;
        _infoMessage = res['message']?.toString() ?? 'Doctor registration submitted! Please wait for admin approval before logging in.';
        notifyListeners();
        return true;
      }

      final token = res['token'];
      ApiService.authToken = token;

      final userMap = res['user'];
      _currentUser = UserModel.fromJson(userMap);

      try {
        final prefs = await SharedPreferences.getInstance();
        if (token != null) {
          await prefs.setString('auth_token', token.toString());
        }
        if (userMap != null) {
          await prefs.setString('user_data', jsonEncode(userMap));
        }
      } catch (e) {
        debugPrint('Error caching session: $e');
      }

      // Sync FCM Device Token & Log Analytics
      NotificationService.syncTokenWithBackend();
      AnalyticsService.logLogin(role: _currentUser?.role ?? 'PATIENT', method: 'register');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> sendRegistrationOtp(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/send-registration-otp', data);
      _isLoading = false;
      notifyListeners();
      return res is Map<String, dynamic> ? res : {'success': true};
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyRegistrationOtp(String phone, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    _pendingApproval = false;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/verify-registration-otp', {
        'phone': phone,
        'otp_code': otp,
      });

      if (res != null && res['pending_approval'] == true) {
        _isLoading = false;
        _pendingApproval = true;
        _infoMessage = res['message']?.toString() ??
            'Doctor registration submitted! Please wait for admin approval before logging in.';
        notifyListeners();
        return true;
      }

      final token = res['token'];
      ApiService.authToken = token?.toString();

      final userMap = res['user'];
      if (userMap != null) {
        _currentUser = UserModel.fromJson(userMap);
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        if (token != null) {
          await prefs.setString('auth_token', token.toString());
        }
        if (userMap != null) {
          await prefs.setString('user_data', jsonEncode(userMap));
        }
      } catch (e) {
        debugPrint('Error caching session: $e');
      }

      // Sync FCM Device Token & Log Analytics
      NotificationService.syncTokenWithBackend();
      AnalyticsService.logLogin(role: _currentUser?.role ?? 'PATIENT', method: 'otp_verify');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> sendForgotPasswordOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.post('/auth/forgot-password', {'phone': phone});
      _isLoading = false;
      notifyListeners();
      return res is Map<String, dynamic> ? res : {'success': true};
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> resetPassword(String phone, String otp, String newPassword, String confirmPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService.post('/auth/reset-password', {
        'phone': phone,
        'otp_code': otp,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUserInfo({String? fullName, String? email, String? phone, String? profilePhoto}) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      fullName: fullName,
      email: email,
      phone: phone,
      profilePhoto: profilePhoto,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
    } catch (e) {
      debugPrint('Error updating cached session: $e');
    }

    notifyListeners();
  }

  Future<bool> uploadProfilePhoto(String base64Image) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.uploadAvatarBase64(base64Image);
      final photoPath = res['profile_photo']?.toString();
      if (photoPath != null) {
        await updateUserInfo(profilePhoto: photoPath);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


  Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('last_synced_fcm_token');
    } catch (e) {
      debugPrint('Error clearing cache session: $e');
    }

    ApiService.authToken = null;
    _currentUser = null;
    notifyListeners();
  }
}
