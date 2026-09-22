import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      debugPrint('[ANALYTICS] Firebase Analytics initialized.');
    } catch (e) {
      debugPrint('[ANALYTICS INIT ERROR] $e');
    }
  }

  /// Log User Login
  static Future<void> logLogin({required String role, String method = 'phone_otp'}) async {
    try {
      await _analytics?.logLogin(loginMethod: method);
      await _analytics?.setUserProperty(name: 'user_role', value: role);
      await _analytics?.logEvent(
        name: 'user_login_success',
        parameters: {
          'role': role,
          'method': method,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  /// Log Appointment Booking
  static Future<void> logAppointmentBooked({
    required int doctorId,
    required int chamberId,
    required String appointmentDate,
    required String tokenDisplay,
    required double totalFee,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'appointment_booked',
        parameters: {
          'doctor_id': doctorId,
          'chamber_id': chamberId,
          'appointment_date': appointmentDate,
          'token_display': tokenDisplay,
          'value': totalFee,
          'currency': 'BDT',
        },
      );
    } catch (_) {}
  }

  /// Log Live Queue Tracker Viewed
  static Future<void> logQueueViewed({required int appointmentId, required String token}) async {
    try {
      await _analytics?.logEvent(
        name: 'live_queue_viewed',
        parameters: {
          'appointment_id': appointmentId,
          'token': token,
        },
      );
    } catch (_) {}
  }

  /// Log Doctor Chamber Status Changed (e.g. Prayer Break, Resumed)
  static Future<void> logDoctorStatusChanged({required String status, String? note}) async {
    try {
      await _analytics?.logEvent(
        name: 'doctor_status_changed',
        parameters: {
          'status': status,
          'note': note ?? '',
        },
      );
    } catch (_) {}
  }

  /// Log Screen View
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics?.logScreenView(screenName: screenName);
    } catch (_) {}
  }
}