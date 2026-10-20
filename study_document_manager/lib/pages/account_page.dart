// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/pages/account_page.dart
// Mô tả: Màn hình quản lý tài khoản và thiết lập Cloud:
//   - Tab 1: Supabase Cloud (Gmail thật - PostgreSQL + RLS + Storage)
//   - Tab 2: Firebase Google (Xác thực Google Sign-In - Checklist 1)
//   - Tab 3: Kiểm thử Offline (SQLite cục bộ - Không cần mạng)
// =====================================================================

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/google_auth_service.dart';
import '../struct/supabase_service.dart';
import '../struct/sync/sync_global.dart';
import '../supabase_options.dart';
import '../widgets/framework/page_framework.dart';
import '../widgets/recommendation/recommended_section.dart';
import 'account_profile_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: PageFramework(
        title: 'Tài khoản & Thiết lập Cloud',
        body: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    icon: Icon(Icons.cloud_done_outlined),
                    text: 'Supabase Cloud',
                  ),
                  Tab(
                    icon: Icon(Icons.g_mobiledata_rounded),
                    text: 'Firebase Google',
                  ),
                  Tab(
                    icon: Icon(Icons.dns_outlined),
                    text: 'Kiểm thử Offline',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SupabaseCloudView(),
                  _FirebaseAuthView(),
                  _LocalDemoAccountsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// TAB 1: CẤU HÌNH & XÁC THỰC SUPABASE CLOUD (GMAIL THẬT + POSTGRESQL + RLS)
// =====================================================================
class _SupabaseCloudView extends StatefulWidget {
  const _SupabaseCloudView();

  @override
  State<_SupabaseCloudView> createState() => _SupabaseCloudViewState();
}

class _SupabaseCloudViewState extends State<_SupabaseCloudView> {
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnecting = false;
  bool _isAuthBusy = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = SupabaseOptions.url;
    _anonKeyController.text = SupabaseOptions.anonKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnect() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = null;
    });

    try {
      final rawUrl = _urlController.text.trim();
      final url = SupabaseOptions.normalizeUrl(rawUrl);
      final anonKey = _anonKeyController.text.trim();

      if (url.isEmpty || anonKey.isEmpty) {
        throw ArgumentError('Vui lòng nhập cả Supabase URL và Anon Key.');
      }

      _urlController.text = url;
      await SupabaseOptions.updateConfig(newUrl: url, newAnonKey: anonKey);
      final ok = await SupabaseService.instance.initialize(
        customUrl: url,
        customAnonKey: anonKey,
      );

      setState(() {
        _isConnecting = false;
        _isError = !ok;
        _statusMessage = ok
            ? 'Kết nối Supabase Cloud thành công!'
            : 'Không thể kết nối. Vui lòng kiểm tra lại URL và Anon Key.';
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isError = true;
        _statusMessage = e.toString();
      });
    }
  }

  Future<void> _signInSupabase() async {
    if (!SupabaseService.instance.isInitialized) {
      await _saveAndConnect();
      if (!SupabaseService.instance.isInitialized) return;
    }

    setState(() {
      _isAuthBusy = true;
      _statusMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        throw ArgumentError('Vui lòng nhập email và mật khẩu.');
      }

      await SupabaseService.instance.signInWithEmail(
        email: email,
        password: password,
      );

      // Cập nhật activeOwnerId trong local SQLite và SyncEngine
      await database.setActiveOwner(email);
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        syncEngine?.updateOwnerId(user.id);
        unawaited(syncEngine?.syncNow());
      }

      if (mounted) {
        setState(() {
          _isAuthBusy = false;
          _isError = false;
          _statusMessage = 'Đăng nhập thành công với tài khoản $email!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập thành công với tài khoản $email!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Tự động chuyển về trang chủ tài liệu sau khi đăng nhập thành công
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthBusy = false;
          _isError = true;
          _statusMessage = 'Đăng nhập thất bại: $e';
        });
      }
    }
  }

  Future<void> _signUpSupabase() async {
    if (!SupabaseService.instance.isInitialized) {
      await _saveAndConnect();
      if (!SupabaseService.instance.isInitialized) return;
    }

    setState(() {
      _isAuthBusy = true;
      _statusMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.length < 6) {
        throw ArgumentError('Mật khẩu cần ít nhất 6 ký tự.');
      }

      await SupabaseService.instance.signUpWithEmail(
        email: email,
        password: password,
      );

      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        await database.setActiveOwner(email);
        syncEngine?.updateOwnerId(user.id);
        unawaited(syncEngine?.syncNow());
      }

      if (mounted) {
        setState(() {
          _isAuthBusy = false;
          _isError = false;
          _statusMessage = 'Đăng ký thành công! Hãy kiểm tra hòm thư nếu cần xác thực.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký tài khoản thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthBusy = false;
          _isError = true;
          _statusMessage = 'Đăng ký thất bại: $e';
        });
      }
    }
  }

  Future<void> _signOutSupabase() async {
    await SupabaseService.instance.signOut();
    setState(() {
      _statusMessage = 'Đã đăng xuất khỏi Supabase.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConnected = SupabaseService.instance.isInitialized;
    final currentUser = SupabaseService.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // -------------------------------------------------------------
        // THẺ THÔNG TIN TÀI KHOẢN ĐANG ĐĂNG NHẬP
        // -------------------------------------------------------------
        if (currentUser != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.primary.withAlpha(60)),
            ),
            color: colorScheme.primaryContainer.withAlpha(40),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          (currentUser.email ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    currentUser.email ?? 'Tài khoản Cloud',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text(
                                        'Cloud Active',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'UID: ${currentUser.id}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Đăng xuất',
                        icon: const Icon(Icons.logout_rounded, color: Colors.red),
                        onPressed: _signOutSupabase,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => UserInterestsDialog(
                            userId: currentUser.id,
                            subjects: database.cachedSubjects,
                            allDocuments: database.cachedDocuments,
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Cài đặt sở thích gợi ý tài liệu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // -------------------------------------------------------------
        // FORM ĐĂNG NHẬP / ĐĂNG KÝ SUPABASE AUTH
        // -------------------------------------------------------------
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_person_outlined, color: colorScheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      currentUser == null
                          ? 'Đăng nhập tài khoản Supabase Cloud'
                          : 'Đăng nhập bằng tài khoản khác',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email tài khoản',
                    hintText: 'user@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isAuthBusy ? null : _signInSupabase,
                        icon: _isAuthBusy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Đăng nhập'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isAuthBusy ? null : _signUpSupabase,
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Đăng ký mới'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (_statusMessage != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isError ? colorScheme.errorContainer : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: _isError ? colorScheme.error : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // -------------------------------------------------------------
        // CẤU HÌNH API SUPABASE CLOUD (EXPANSION TILE THU GỌN GỌN GÀNG)
        // -------------------------------------------------------------
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
          ),
          child: ExpansionTile(
            initiallyExpanded: !isConnected,
            leading: Icon(
              isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: isConnected ? Colors.green : Colors.amber,
            ),
            title: const Text(
              'Cấu hình kết nối API Supabase Cloud',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              isConnected
                  ? 'Đã kết nối: ${SupabaseOptions.url}'
                  : 'Chưa thiết lập URL & Anon Key',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Supabase Project URL',
                  hintText: 'https://xxxx.supabase.co',
                  helperText: 'URL định dạng: https://<project-ref>.supabase.co',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _anonKeyController,
                decoration: InputDecoration(
                  labelText: 'Supabase Anon / Public Key',
                  prefixIcon: const Icon(Icons.key),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isConnecting ? null : _saveAndConnect,
                  icon: _isConnecting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Lưu & Kết nối Supabase'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// TAB 2: XÁC THỰC GOOGLE QUA FIREBASE AUTH (CHECKLIST 1)
// =====================================================================
class _FirebaseAuthView extends StatefulWidget {
  const _FirebaseAuthView();

  @override
  State<_FirebaseAuthView> createState() => _FirebaseAuthViewState();
}

class _FirebaseAuthViewState extends State<_FirebaseAuthView> {
  bool _isBusy = false;
  String? _errorMessage;

  Future<void> _signInGoogle() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await GoogleAuthService.instance.signInWithGoogle();
    } on fb.FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message ?? error.code);
    } on GoogleSignInException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.description ?? error.code.name);
      }
    } on StateError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signOutGoogle() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await GoogleAuthService.instance.signOut();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConfigured = GoogleAuthService.instance.isConfigured;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blue.withAlpha(60)),
          ),
          color: Colors.blue.withAlpha(15),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Checklist 1: Firebase Google Authentication',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  '• Firebase Auth hỗ trợ Google Sign-In hoàn toàn miễn phí trọn đời (0đ), KHÔNG cần thẻ tín dụng.\n'
                  '• Firebase Storage cung cấp 5 GB lưu trữ file miễn phí trong gói Spark.\n'
                  '• Chạy ứng dụng với cờ kích hoạt Firebase:\n'
                  '  flutter run --dart-define=ENABLE_FIREBASE=true',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!isConfigured) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 40, color: colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase hiện ở chế độ Tắt mặc định.\n'
                    'Để đăng nhập Google qua Firebase trên thiết bị thật, chạy lệnh:\n'
                    'flutter run --dart-define=ENABLE_FIREBASE=true',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          StreamBuilder<fb.User?>(
            stream: GoogleAuthService.instance.authStateChanges,
            builder: (context, snapshot) {
              final user = snapshot.data;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      if (user?.photoURL case final photoUrl?)
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(photoUrl),
                        )
                      else
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.person, size: 36, color: colorScheme.primary),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        user?.displayName ?? 'Chưa đăng nhập Google',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => pushRoute(
                              context,
                              AccountProfilePage(
                                user: user,
                                onSignOut: _signOutGoogle,
                              ),
                            ),
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Xem hồ sơ & Cài đặt sở thích gợi ý'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: user == null
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isBusy ? null : _signInGoogle,
                                icon: const Icon(Icons.login),
                                label: const Text('Đăng nhập bằng Google'),
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isBusy ? null : _signOutGoogle,
                                icon: const Icon(Icons.logout),
                                label: const Text('Đăng xuất Google'),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// =====================================================================
// TAB 3: MÔ PHỎNG PHÂN QUYỀN OFFLINE (SQLITE CỤC BỘ - KHÔNG CẦN MẠNG)
// =====================================================================
class _LocalDemoAccountsView extends StatefulWidget {
  const _LocalDemoAccountsView();

  @override
  State<_LocalDemoAccountsView> createState() => _LocalDemoAccountsViewState();
}

class _LocalDemoAccountsViewState extends State<_LocalDemoAccountsView> {
  static const Map<String, String> _accounts = {
    'local': 'Tài khoản 1 (Owner - Chủ sở hữu)',
    'demo-user-1': 'Tài khoản 2 (Viewer - Người xem)',
    'demo-user-2': 'Tài khoản 3 (Editor - Người chỉnh sửa)',
    'demo-user-3': 'Tài khoản 4 (Stranger - Người lạ)',
  };

  bool _isBusy = false;
  String? _errorMessage;

  Future<void> _switchAccount(String? ownerId) async {
    if (ownerId == null || ownerId == database.activeOwnerId) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await database.setActiveOwner(ownerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển sang tài khoản: ${_accounts[ownerId]}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOwnerId = database.activeOwnerId;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withAlpha(90),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.offline_bolt_outlined, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Kiểm thử phân quyền Offline (SQLite)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cơ chế phân quyền truy cập hoạt động trực tiếp trên SQLite máy bạn, '
                  'phục vụ chấm bài hoặc kiểm tra tính năng khi không có kết nối internet.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _accounts.containsKey(activeOwnerId) ? activeOwnerId : 'local',
          decoration: InputDecoration(
            labelText: 'Tài khoản SQLite hiện đang sử dụng',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.person_pin_circle_outlined),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: _accounts.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text('${entry.value} [${entry.key}]'),
                ),
              )
              .toList(),
          onChanged: _isBusy ? null : _switchAccount,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => UserInterestsDialog(
                userId: activeOwnerId,
                subjects: database.cachedSubjects,
                allDocuments: database.cachedDocuments,
              ),
            );
          },
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text('Cài đặt sở thích gợi ý cho "$activeOwnerId"'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
        ],
        const SizedBox(height: 28),
        Text(
          'Kịch bản kiểm thử mẫu (4 bước):',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 14),
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('1')),
          title: Text('Đăng nhập "local" (Chủ sở hữu)'),
          subtitle: Text(
            'Tạo tài liệu mới, bấm nút "Chia sẻ". Cấp quyền demo-user-1 (Chỉ xem) và demo-user-2 (Có thể sửa).',
          ),
        ),
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('2')),
          title: Text('Chuyển sang "demo-user-1" (Viewer)'),
          subtitle: Text(
            'Tài liệu xuất hiện trong danh sách. Thử sửa tiêu đề -> Ứng dụng từ chối! Nút xóa bị ẩn.',
          ),
        ),
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('3')),
          title: Text('Chuyển sang "demo-user-2" (Editor)'),
          subtitle: Text(
            'Mở tài liệu và bấm Sửa -> Cập nhật thành công! Thử xóa hoặc phân quyền -> Bị từ chối.',
          ),
        ),
        const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('4')),
          title: Text('Chuyển sang "demo-user-3" (Stranger)'),
          subtitle: Text(
            'Tài liệu hoàn toàn không xuất hiện, tìm kiếm không ra kết quả (Bảo vệ dữ liệu tuyệt đối).',
          ),
        ),
      ],
    );
  }
}
