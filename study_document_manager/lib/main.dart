import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'database/app_database.dart';
import 'database/databaseGlobal.dart';
import 'firebase_options.dart';
import 'pages/auth_gate.dart';
import 'struct/firebase_platform_support.dart';
import 'struct/supabase_service.dart';
import 'struct/sync/local_file_store_factory.dart';
import 'struct/sync/mock_remote_sync_service.dart';
import 'struct/sync/network_monitor.dart';
import 'struct/sync/remote_sync_service.dart';
import 'struct/sync/supabase_remote_sync_service.dart';
import 'struct/sync/sync_engine.dart';
import 'struct/sync/sync_global.dart';
import 'supabase_options.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - ĐIỂM KHỞI CHẠY ỨNG DỤNG (ENTRY POINT)]
// File: lib/main.dart
// Đề tài: TH1 - Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew
// Mô tả: Khởi tạo cơ sở dữ liệu SQLite, tầng đồng bộ Offline-First
// (SyncEngine + RemoteSyncService + NetworkMonitor), hỗ trợ cả
// Firebase Auth/Storage và Supabase PostgreSQL/Storage/Auth.
// =====================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo cấu hình Supabase (nếu có URL & Key)
  await SupabaseOptions.loadSavedConfig();
  if (SupabaseOptions.isConfigured) {
    await SupabaseService.instance.initialize();
  }

  const enableFirebase = bool.fromEnvironment(
    'ENABLE_FIREBASE',
    defaultValue: false,
  );
  if (enableFirebase && isFirebaseConfiguredPlatform) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  }

  database = AppDatabase();
  if (canUseFirebase) {
    await database.setActiveOwner(FirebaseAuth.instance.currentUser?.uid);
  }
  await database.init();

  await _bootstrapSync();

  runApp(const StudyDocumentApp());
}

Future<void> _bootstrapSync() async {
  final fileStore = await createDefaultLocalFileStore();
  // Sử dụng Supabase sync thật khi đã kết nối, hoặc Mock adapter cục bộ
  final RemoteSyncService remote = SupabaseService.instance.isInitialized
      ? SupabaseRemoteSyncService()
      : MockRemoteSyncService();

  syncEngine = SyncEngine(
    database: database,
    remote: remote,
    fileStore: fileStore,
    ownerId: _resolveOwnerId(),
  );
  await syncEngine!.initialize();
  syncEngine!.bindNetworkMonitor(
    HeartbeatNetworkMonitor(
      remote: remote,
      interval: const Duration(seconds: 15),
    ),
  );
}

String _resolveOwnerId() {
  if (canUseFirebase && FirebaseAuth.instance.currentUser?.uid != null) {
    return FirebaseAuth.instance.currentUser!.uid;
  }
  if (SupabaseService.instance.currentUser?.id != null) {
    return SupabaseService.instance.currentUser!.id;
  }
  return database.activeOwnerId;
}

class StudyDocumentApp extends StatefulWidget {
  const StudyDocumentApp({super.key});

  @override
  State<StudyDocumentApp> createState() => _StudyDocumentAppState();
}

class _StudyDocumentAppState extends State<StudyDocumentApp> {
  StreamSubscription<User?>? _authOwnerSubscription;

  @override
  void initState() {
    super.initState();
    if (canUseFirebase) {
      _authOwnerSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) => _updateOwner(user?.uid),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Không thể đọc trạng thái xác thực: $error');
        },
      );
    }
  }

  Future<void> _updateOwner(String? userId) async {
    try {
      await database.setActiveOwner(userId);
    } catch (error, stackTrace) {
      debugPrint(
        'Không thể cập nhật phạm vi dữ liệu theo tài khoản: $error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    _authOwnerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Tài Liệu Học Tập (Kiến trúc Cashew)',
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
