import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../struct/firebase_platform_support.dart';
import '../struct/google_auth_service.dart';
import 'home_page.dart';

// =====================================================================
// AUTH GATE — Cổng xác thực (Offline-First)
// Firebase login là TÙY CHỌN: app hoạt động đầy đủ mà không cần đăng nhập.
// Người dùng có thể đăng nhập Google sau qua tab "Firebase Google" → Tài khoản.
// =====================================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Nếu Firebase không khả dụng → vào thẳng HomePage (chế độ offline)
    if (!canUseFirebase) {
      return const HomePage();
    }

    return StreamBuilder<User?>(
      stream: GoogleAuthService.instance.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        // Đang chờ Firebase khởi tạo → hiển thị loading ngắn
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingPage();
        }

        // Mọi trường hợp khác (đã đăng nhập, chưa đăng nhập, lỗi Firebase)
        // đều vào HomePage. Đăng nhập Google là tùy chọn.
        return const HomePage();
      },
    );
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang khởi động...'),
          ],
        ),
      ),
    );
  }
}

