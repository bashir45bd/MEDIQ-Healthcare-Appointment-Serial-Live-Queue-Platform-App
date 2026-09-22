import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'connectivity_service.dart';

class ApiService {
  static String? authToken;
  static String? _workingBaseUrl;

  // Candidate base URLs in priority order:
  // 1. Production Secure HTTPS API
  // 2. Local WiFi / LAN IP (Development)
  // 3. Android Studio Emulator (10.0.2.2)
  // 4. Localhost / Chrome
  static final List<String> _candidateUrls = [
    'https://api.mediq.com.bd/api/v1',
    'http://192.168.42.129/mediq/backend/public/api/v1',
    'http://10.0.2.2/mediq/backend/public/api/v1',
    'http://localhost/mediq/backend/public/api/v1',
  ];

  static Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-App-Platform': 'mediq-flutter-mobile',
      'X-App-Version': '1.0.0',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $authToken';
    }
    return h;
  }

  static Future<String> _resolveBaseUrl() async {
    if (_workingBaseUrl != null) return _workingBaseUrl!;

    for (final base in _candidateUrls) {
      try {
        final uri = Uri.parse('$base/specialties');
        final response = await http.get(uri).timeout(const Duration(seconds: 2));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          _workingBaseUrl = base;
          ConnectivityService.instance.reportSuccess();
          return base;
        }
      } catch (_) {
        // Try next candidate URL
      }
    }

    _workingBaseUrl = _candidateUrls.first;
    return _workingBaseUrl!;
  }

  static Future<dynamic> get(String endpoint) async {
    final base = await _resolveBaseUrl();
    try {
      final uri = Uri.parse('$base$endpoint');
      final response = await http.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      _workingBaseUrl = null;
      try {
        final retryBase = await _resolveBaseUrl();
        final uri = Uri.parse('$retryBase$endpoint');
        final response = await http.get(uri, headers: _headers);
        return _handleResponse(response);
      } catch (err) {
        if (err is SocketException || err is http.ClientException) {
          ConnectivityService.instance.reportFailure();
        }
        rethrow;
      }
    }
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final base = await _resolveBaseUrl();
    try {
      final uri = Uri.parse('$base$endpoint');
      final response = await http.post(uri, headers: _headers, body: jsonEncode(body));
      return _handleResponse(response);
    } catch (e) {
      _workingBaseUrl = null;
      try {
        final retryBase = await _resolveBaseUrl();
        final uri = Uri.parse('$retryBase$endpoint');
        final response = await http.post(uri, headers: _headers, body: jsonEncode(body));
        return _handleResponse(response);
      } catch (err) {
        if (err is SocketException || err is http.ClientException) {
          ConnectivityService.instance.reportFailure();
        }
        rethrow;
      }
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final base = await _resolveBaseUrl();
    final uri = Uri.parse('$base$endpoint');
    final response = await http.put(uri, headers: _headers, body: jsonEncode(body));
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final base = await _resolveBaseUrl();
    final uri = Uri.parse('$base$endpoint');
    final response = await http.delete(uri, headers: _headers);
    return _handleResponse(response);
  }

  static String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = _workingBaseUrl ?? _candidateUrls.first;
    final publicRoot = base.replaceAll('/api/v1', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$publicRoot/$cleanPath';
  }

  static Future<dynamic> uploadAvatarBase64(String base64Data) async {
    return post('/users/avatar', {'avatar': base64Data});
  }

  static dynamic _handleResponse(http.Response response) {
    ConnectivityService.instance.reportSuccess();
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['data'];
    } else {
      final message = body['error']?['message'] ?? 'An unexpected error occurred';
      throw Exception(message);
    }
  }
}
