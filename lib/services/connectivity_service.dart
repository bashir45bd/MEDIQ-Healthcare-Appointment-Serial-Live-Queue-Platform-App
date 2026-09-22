import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  final ValueNotifier<bool> justReconnected = ValueNotifier<bool>(false);

  Timer? _pollingTimer;
  Timer? _reconnectedDismissTimer;
  bool _isChecking = false;

  void initialize() {
    // Initial check
    checkConnectionNow();

    // Fast periodic check every 7 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      checkConnectionNow();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _reconnectedDismissTimer?.cancel();
  }

  /// Instant manual/automated check
  Future<bool> checkConnectionNow() async {
    if (_isChecking) return isOnline.value;
    _isChecking = true;

    bool online = false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 2500));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        online = true;
      }
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(milliseconds: 2000));
        if (fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty) {
          online = true;
        }
      } catch (_) {
        online = false;
      }
    } finally {
      _isChecking = false;
    }

    _updateState(online);
    return online;
  }

  /// Instant notification called directly by ApiService on network exceptions
  void reportFailure() {
    _updateState(false);
  }

  /// Called by ApiService on successful network responses
  void reportSuccess() {
    if (!isOnline.value) {
      _updateState(true);
    }
  }

  void _updateState(bool online) {
    if (isOnline.value != online) {
      isOnline.value = online;
      if (online) {
        // Show "Connected" flash banner
        justReconnected.value = true;
        _reconnectedDismissTimer?.cancel();
        _reconnectedDismissTimer = Timer(const Duration(seconds: 3), () {
          justReconnected.value = false;
        });
      } else {
        justReconnected.value = false;
      }
    }
  }
}
