// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/supabase_options.dart
// Mô tả: Quản lý cấu hình kết nối Supabase Cloud (URL & Anon Key).
// Hỗ trợ 2 phương thức cấu hình:
//   1. Qua biến biên dịch: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
//   2. Cấu hình động qua giao diện ứng dụng (lưu trữ trong SharedPreferences)
// Tự động chuẩn hóa URL (chống lỗi 404 khi dán link Dashboard).
// =====================================================================

import 'package:shared_preferences/shared_preferences.dart';

class SupabaseOptions {
  static const String _defaultUrl = '';
  static const String _envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _defaultAnonKey =
      '';
  static const String _envAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String prefKeyUrl = 'custom_supabase_url';
  static const String prefKeyAnonKey = 'custom_supabase_anon_key';

  static String _currentUrl =
      normalizeUrl(_envUrl.isNotEmpty ? _envUrl : _defaultUrl);
  static String _currentAnonKey =
      _envAnonKey.isNotEmpty ? _envAnonKey : _defaultAnonKey;

  static String get url => _currentUrl;
  static String get anonKey => _currentAnonKey;

  static bool get isConfigured =>
      _currentUrl.trim().isNotEmpty && _currentAnonKey.trim().isNotEmpty;

  /// Chuẩn hóa URL để tránh lỗi 404 (ví dụ người dùng dán nhầm link Dashboard)
  static String normalizeUrl(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // 1. Nếu dán nhầm link Dashboard trên trình duyệt:
    // https://supabase.com/dashboard/project/abcxyz...
    final dashboardMatch = RegExp(
      r'supabase\.com/dashboard/project/([a-zA-Z0-9_-]+)',
    ).firstMatch(trimmed);
    if (dashboardMatch != null) {
      final projectRef = dashboardMatch.group(1);
      return 'https://$projectRef.supabase.co';
    }

    // 2. Nếu dán URL có path (ví dụ: https://xxxx.supabase.co/rest/v1 hoặc có dấu / cuối)
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      if (uri.host == 'supabase.com') {
        final segments = uri.pathSegments;
        final projIndex = segments.indexOf('project');
        if (projIndex >= 0 && projIndex + 1 < segments.length) {
          return 'https://${segments[projIndex + 1]}.supabase.co';
        }
      }
      final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'https';
      return '$scheme://${uri.host}';
    }

    // 3. Nếu người dùng chỉ gõ mỗi mã Project Ref (20 ký tự)
    if (RegExp(r'^[a-zA-Z0-9_-]{20}$').hasMatch(trimmed)) {
      return 'https://$trimmed.supabase.co';
    }

    return trimmed;
  }

  /// Nạp cấu hình đã lưu từ SharedPreferences
  static Future<void> loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(prefKeyUrl);
      final savedKey = prefs.getString(prefKeyAnonKey);

      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _currentUrl = normalizeUrl(savedUrl);
      }
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _currentAnonKey = savedKey.trim();
      }
    } catch (_) {
      // Bỏ qua lỗi SharedPreferences nếu chạy trong test môi trường tối giản
    }
  }

  /// Cập nhật cấu hình mới và lưu vào máy
  static Future<void> updateConfig({
    required String newUrl,
    required String newAnonKey,
  }) async {
    _currentUrl = normalizeUrl(newUrl);
    _currentAnonKey = newAnonKey.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyUrl, _currentUrl);
      await prefs.setString(prefKeyAnonKey, _currentAnonKey);
    } catch (_) {}
  }

  /// Xóa cấu hình tùy chỉnh để quay về mặc định
  static Future<void> clearConfig() async {
    _currentUrl = normalizeUrl(_envUrl.isNotEmpty ? _envUrl : _defaultUrl);
    _currentAnonKey = _envAnonKey.isNotEmpty ? _envAnonKey : _defaultAnonKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefKeyUrl);
      await prefs.remove(prefKeyAnonKey);
    } catch (_) {}
  }
}
