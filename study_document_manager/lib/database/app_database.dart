import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:uuid/uuid.dart';

import '../struct/models/document_models.dart';
import '../struct/models/borrow_request_model.dart';
import '../struct/models/document_permission.dart';
import '../struct/models/sync_models.dart';
import 'tables.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG DỮ LIỆU: BỘ ĐIỀU KHIỂN CƠ SỞ DỮ LIỆU (DATABASE ENGINE & DAO)]
// File: lib/database/app_database.dart
// Mô tả: Quản lý kết nối SQLite, khởi tạo Schema, cung cấp các phương thức
// DAO (Thêm, Sửa, Xóa, Truy vấn, Tìm kiếm) và luồng dữ liệu phản ứng (Reactive Stream)
// tương tự pattern watchAll() trong kiến trúc Cashew.
// Hỗ trợ chế độ In-Memory Fallback tự động khi chạy trên trình duyệt Web (Chrome).
// =====================================================================

class AppDatabase {
  static const String sharedOwnerId = '__shared__';

  Database? _db;
  bool _useMemoryFallback = false;
  String _activeOwnerId = 'local';
  final List<SubjectModel> _memorySubjects = [];
  final List<String> _memorySubjectOwners = [];
  final List<DocumentModel> _memoryDocuments = [];
  final List<String> _memoryDocumentOwners = [];
  final List<DocumentPermission> _memoryPermissions = [];

  final List<DeleteLogModel> _memoryDeleteLogs = [];
  final List<SyncOutboxEntry> _memoryOutbox = [];
  final Map<String, String> _memorySyncState = {};
  final List<BorrowRequestModel> _memoryBorrowRequests = [];


  // Bộ nhớ đệm đồng bộ (In-Memory Cache) theo phong cách Cashew
  List<DocumentModel> _cachedDocuments = [];
  List<SubjectModel> _cachedSubjects = [];

  List<DocumentModel> get cachedDocuments => List.unmodifiable(_cachedDocuments);
  List<SubjectModel> get cachedSubjects => List.unmodifiable(_cachedSubjects);

  // StreamController để phát tín hiệu cập nhật tự động (Reactive Stream)
  final _documentsStreamController =
      StreamController<List<DocumentModel>>.broadcast();
  final _subjectsStreamController =
      StreamController<List<SubjectModel>>.broadcast();

  Stream<List<DocumentModel>> get watchAllDocuments =>
      _documentsStreamController.stream;
  Stream<List<SubjectModel>> get watchAllSubjects =>
      _subjectsStreamController.stream;
  final _borrowRequestsStreamController =
      StreamController<List<BorrowRequestModel>>.broadcast();
  Stream<List<BorrowRequestModel>> get watchAllBorrowRequests =>
      _borrowRequestsStreamController.stream;

  String get activeOwnerId => _activeOwnerId;

  Future<void> setActiveOwner(String? userId) async {
    final nextOwnerId = userId == null || userId.isEmpty ? 'local' : userId;
    if (_activeOwnerId == nextOwnerId) return;
    _activeOwnerId = nextOwnerId;
    if (_db == null && !_useMemoryFallback) return;
    await _seedPrivateDataForActiveOwner();
    await notifyDocumentsChanged();
    await notifySubjectsChanged();
  }

  /// v5 adds document sharing permissions.
  static const int schemaVersion = 6;

  /// Khởi tạo và mở cơ sở dữ liệu
  Future<void> init({bool isInMemory = false}) async {
    if (kIsWeb) {
      // Trên Web Chrome: Thử dùng WebAssembly không cần Web Worker
      try {
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
        final path = isInMemory ? inMemoryDatabasePath : 'cashew_study_docs.db';

        _db = await _openDatabase(path);

      } catch (e) {
        debugPrint(
          '[Cashew AppDatabase] Web SQLite không khả dụng trên trình duyệt này, tự động kích hoạt bộ nhớ In-Memory Fallback: $e',
        );
        _useMemoryFallback = true;
        _seedMemoryFallbackData();
      }
    } else {
      // Hỗ trợ Desktop (Windows, Linux, macOS) và môi trường UnitTest
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      String path;
      if (isInMemory) {
        path = inMemoryDatabasePath;
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        path = p.join(docsDir.path, 'cashew_study_docs.db');
      }


      _db = await _openDatabase(path);

    }

    if (_db != null) {
      await _seedSharedData(_db!);
    }
    await _seedPrivateDataForActiveOwner();
    // Kích hoạt việc đẩy dữ liệu ban đầu vào Streams
    await notifyDocumentsChanged();
    await notifySubjectsChanged();
  }


  Future<Database> _openDatabase(String path) {
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _migrateSchema,
    );
  }

  /// Tạo toàn bộ Schema cho lần cài đặt đầu tiên.
  Future<void> _createSchema(Database db, int version) async {
    await db.execute(SubjectTable.createTableSql);
    await db.execute(DocumentTable.createTableSql);
    await db.execute(DeleteLogTable.createTableSql);
    await db.execute(SyncOutboxTable.createTableSql);
    await db.execute(SyncStateTable.createTableSql);
    await db.execute(SubjectTable.createOwnerIndexSql);
    await db.execute(DocumentTable.createOwnerIndexSql);
    await db.execute(DocumentPermissionTable.createTableSql);
    await db.execute(DocumentPermissionTable.createRecipientIndexSql);
    await db.execute(BorrowRequestTable.createTableSql);
    await db.execute(BorrowRequestTable.createBorrowerIndexSql);
    await db.execute(BorrowRequestTable.createOwnerIndexSql);
    await db.execute(BorrowRequestTable.createDocIndexSql);
    await db.execute(BorrowRequestTable.createStatusIndexSql);
    await _seedDefaultData(db);
  }

  /// Nâng cấp Schema theo từng bước (migration) khi ứng dụng được cập nhật.
  Future<void> _migrateSchema(

    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(

        'ALTER TABLE ${DocumentTable.tableName} '
        'ADD COLUMN ${DocumentTable.colStoragePath} TEXT',
      );
    }
    if (oldVersion < 3) {
      for (final column in DocumentTable.syncColumns) {
        await db.execute(
          'ALTER TABLE ${DocumentTable.tableName} ADD COLUMN $column',
        );
      }
      await db.execute(DeleteLogTable.createTableSql);
      await db.execute(SyncOutboxTable.createTableSql);
      await db.execute(SyncStateTable.createTableSql);

    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE ${SubjectTable.tableName} '
        'ADD COLUMN ${SubjectTable.colOwnerId} TEXT NOT NULL DEFAULT \'local\'',
      );
      await db.execute(
        'ALTER TABLE ${DocumentTable.tableName} '
        'ADD COLUMN ${DocumentTable.colOwnerId} TEXT NOT NULL DEFAULT \'local\'',
      );
    }
    if (oldVersion < 5) {
      await db.execute(DocumentPermissionTable.createTableSql);
      await db.execute(DocumentPermissionTable.createRecipientIndexSql);
    }
    if (oldVersion < 6) {
      for (final column in DocumentTable.schemaV6Columns) {
        try {
          await db.execute('ALTER TABLE ${DocumentTable.tableName} ADD COLUMN $column');
        } catch (_) {}
      }
      await db.execute(BorrowRequestTable.createTableSql);
      await db.execute(BorrowRequestTable.createBorrowerIndexSql);
      await db.execute(BorrowRequestTable.createOwnerIndexSql);
      await db.execute(BorrowRequestTable.createDocIndexSql);
      await db.execute(BorrowRequestTable.createStatusIndexSql);
    }
    await db.execute(SubjectTable.createOwnerIndexSql);
    await db.execute(DocumentTable.createOwnerIndexSql);
  }

  /// Nạp dữ liệu mẫu ban đầu vào SQLite Database
  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now();

    final defaultSubjects = _buildInitialSubjects(now);
    for (final s in defaultSubjects) {
      await db.insert(SubjectTable.tableName, {
        ...s.toMap(),
        SubjectTable.colOwnerId: 'local',
      });
    }

    final defaultDocs = _buildInitialDocuments(now);
    for (final doc in defaultDocs) {
      await db.insert(DocumentTable.tableName, {
        ...doc.toMap(),
        DocumentTable.colOwnerId: 'local',
      });
    }

    // Nạp sẵn 1 yêu cầu mượn mẫu: Bob gửi yêu cầu mượn sách của Alice
    final sampleReq = BorrowRequestModel(
      id: 'req_sample_bob_to_alice',
      documentId: 'doc_1',
      borrowerId: 'bob@tlu.edu.vn',
      borrowerEmail: 'bob@tlu.edu.vn',
      ownerId: 'local',
      status: 'pending',
      requestDate: now.subtract(const Duration(hours: 4)),
      dueDate: now.add(const Duration(days: 5)),
      note: 'Chào bạn Alice, mình muốn mượn cuốn giáo trình Flutter này để ôn thi trong 5 ngày nhé!',
      createdDate: now.subtract(const Duration(hours: 4)),
      updatedDate: now.subtract(const Duration(hours: 4)),
      documentTitle: 'Giáo trình Lập trình Ứng dụng Di động với Flutter',
      borrowerName: 'Bob Trần (bob@tlu.edu.vn)',
      ownerEmail: 'alice@tlu.edu.vn',
    );
    await db.insert(
      BorrowRequestTable.tableName,
      sampleReq.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _seedSharedData(Database db) async {
    final now = DateTime.now();
    final sharedSubject = _buildSharedSubject(now);
    await db.insert(
      SubjectTable.tableName,
      {
        ...sharedSubject.toMap(),
        SubjectTable.colOwnerId: sharedOwnerId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    for (final document in _buildSharedDocuments(now, sharedSubject.id)) {
      await db.insert(
        DocumentTable.tableName,
        {
          ...document.toMap(),
          DocumentTable.colOwnerId: sharedOwnerId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  SubjectModel _buildSharedSubject(DateTime now) => SubjectModel(
    id: 'shared_sub_swe',
    name: 'Kiến trúc & Thiết kế Phần mềm',
    code: 'SWE302',
    colorValue: 0xFF1E88E5,
    iconName: 'architecture',
    createdDate: now,
    isShared: true,
  );

  List<DocumentModel> _buildSharedDocuments(DateTime now, String subjectId) {
    return [
      DocumentModel(
        id: 'shared_doc_swe_lecture_01',
        title: 'Bài giảng chung: Tổng quan kiến trúc phần mềm',
        subjectId: subjectId,
        type: DocumentType.lecture,
        notes: 'Tài liệu tham khảo chung dành cho mọi tài khoản.',
        tags: const ['Bài giảng', 'Kiến trúc phần mềm', 'Chung'],
        status: DocumentStatus.completed,
        createdDate: now,
        updatedDate: now,
        isShared: true,
      ),
      DocumentModel(
        id: 'shared_doc_swe_assignment_01',
        title: 'Bài tập chung: Phân tích kiến trúc ứng dụng',
        subjectId: subjectId,
        type: DocumentType.assignment,
        notes: 'Bài tập mẫu dùng chung; mỗi tài khoản tự tạo bản làm riêng.',
        tags: const ['Bài tập', 'Kiến trúc phần mềm', 'Chung'],
        deadline: now.add(const Duration(days: 14)),
        createdDate: now,
        updatedDate: now,
        isShared: true,
      ),
    ];
  }

  Future<void> _seedPrivateDataForActiveOwner() async {
    final ownerId = _activeOwnerId;
    if (ownerId == 'local' || ownerId == sharedOwnerId) return;

    final ownerKey = base64Url.encode(utf8.encode(ownerId)).replaceAll('=', '');
    final subjectId = 'private_sub_$ownerKey';
    if (await getSubjectById(subjectId) == null) {
      await insertSubject(
        SubjectModel(
          id: subjectId,
          name: 'Bài tập cá nhân',
          code:
              'CN-${ownerKey.substring(0, ownerKey.length < 8 ? ownerKey.length : 8)}',
          colorValue: 0xFF7E57C2,
          iconName: 'assignment',
          createdDate: DateTime.now(),
        ),
      );
    }

    final now = DateTime.now();
    final seededAssignments = [
      DocumentModel(
        id: 'private_assignment_${ownerKey}_01',
        title: 'Bài tập cá nhân: Ôn tập kiến thức môn học',
        subjectId: subjectId,
        type: DocumentType.assignment,
        notes: 'Bài tập riêng của tài khoản này. Có thể chỉnh sửa hoặc xóa.',
        tags: const ['Cá nhân', 'Ôn tập'],
        deadline: now.add(const Duration(days: 7)),
        createdDate: now,
        updatedDate: now,
      ),
      DocumentModel(
        id: 'private_assignment_${ownerKey}_02',
        title: 'Bài tập cá nhân: Hoàn thành báo cáo tuần',
        subjectId: subjectId,
        type: DocumentType.assignment,
        notes: 'Dữ liệu bài tập riêng, không hiển thị với tài khoản khác.',
        tags: const ['Cá nhân', 'Báo cáo'],
        deadline: now.add(const Duration(days: 10)),
        createdDate: now,
        updatedDate: now,
      ),
    ];
    for (final document in seededAssignments) {
      if (await getDocumentById(document.id) == null) {
        await insertDocument(document);
      }
    }
  }

  /// Nạp dữ liệu mẫu vào bộ nhớ In-Memory khi chạy Web Fallback
  void _seedMemoryFallbackData() {
    final now = DateTime.now();
    _memorySubjects.clear();
    _memorySubjects.addAll(_buildInitialSubjects(now));
    _memorySubjectOwners
      ..clear()
      ..addAll(List.filled(_memorySubjects.length, 'local'));
    _memoryDocuments.clear();
    _memoryDocuments.addAll(_buildInitialDocuments(now));
    _memoryDocumentOwners
      ..clear()
      ..addAll(List.filled(_memoryDocuments.length, 'local'));
    final sharedSubject = _buildSharedSubject(now);
    _memorySubjects.add(sharedSubject);
    _memorySubjectOwners.add(sharedOwnerId);
    final sharedDocuments = _buildSharedDocuments(now, sharedSubject.id);
    _memoryDocuments.addAll(sharedDocuments);
    _memoryDocumentOwners.addAll(
      List.filled(sharedDocuments.length, sharedOwnerId),
    );
    _memoryPermissions.clear();

    _memoryDeleteLogs.clear();
    _memoryOutbox.clear();
    _memorySyncState.clear();
    _memoryBorrowRequests.clear();

    // Seed borrow request mẫu: Bob mượn tài liệu doc_1 của Alice (local)
    _memoryBorrowRequests.addAll([
      BorrowRequestModel(
        id: 'req_bob_borrows_doc1',
        documentId: 'doc_1',
        borrowerId: 'bob@tlu.edu.vn',
        borrowerEmail: 'bob@tlu.edu.vn',
        borrowerName: 'Bob Trần',
        ownerId: 'local',
        ownerEmail: 'alice@tlu.edu.vn',
        documentTitle: 'Slide Bài giảng Flutter: Kiến trúc BLoC & Firebase Integration',
        status: 'pending',
        requestDate: now.subtract(const Duration(hours: 3)),
        dueDate: now.add(const Duration(days: 7)),
        note: 'Mình cần tài liệu này để chuẩn bị cho buổi báo cáo TH2. '
            'Cho mình mượn khoảng 1 tuần được không?',
      ),
      BorrowRequestModel(
        id: 'req_charlie_borrows_doc4',
        documentId: 'doc_4',
        borrowerId: 'charlie@tlu.edu.vn',
        borrowerEmail: 'charlie@tlu.edu.vn',
        borrowerName: 'Charlie Lê',
        ownerId: 'local',
        ownerEmail: 'alice@tlu.edu.vn',
        documentTitle: 'Đề thi Cuối kỳ mẫu: Cấu trúc Dữ liệu & Giải thuật',
        status: 'approved',
        requestDate: now.subtract(const Duration(days: 2)),
        dueDate: now.add(const Duration(days: 5)),
        note: 'Cần ôn thi cuối kỳ DSA. Cảm ơn bạn Alice!',
      ),
    ]);

  }

  List<SubjectModel> _buildInitialSubjects(DateTime now) {
    return [
      SubjectModel(
        id: 'sub_mob',
        name: 'Phát triển Di động Đa nền tảng',
        code: 'CSE441',
        colorValue: 0xFF43A047,
        iconName: 'phone_android',
        createdDate: now,
      ),
      SubjectModel(
        id: 'sub_swe',
        name: 'Kiến trúc & Thiết kế Phần mềm',
        code: 'SWE302',
        colorValue: 0xFF1E88E5,
        iconName: 'architecture',
        createdDate: now,
      ),
      SubjectModel(
        id: 'sub_dsa',
        name: 'Cấu trúc Dữ liệu & Giải thuật',
        code: 'DSA201',
        colorValue: 0xFFFB8C00,
        iconName: 'account_tree',
        createdDate: now,
      ),
    ];
  }

  List<DocumentModel> _buildInitialDocuments(DateTime now) {
    // Tọa độ khuôn viên ĐH Thủy Lợi (Hà Nội)
    const double tluLat = 21.00745;
    const double tluLng = 105.82472;

    return [
      DocumentModel(
        id: 'doc_1',
        title: 'Slide Bài giảng Flutter: Kiến trúc BLoC & Firebase Integration',
        subjectId: 'sub_mob',
        type: DocumentType.lecture,
        notes:
            'Trình bày kiến trúc BLoC, tích hợp Firebase Auth + Supabase PostgreSQL trong ứng dụng Flutter đa nền tảng. '
            'Tài liệu vật lý lưu tại Thư viện ĐH Thủy Lợi, tầng 2, kệ C-12.',
        fileUrl: 'https://flutter.dev/docs/development/data-and-backend/state-mgmt/bloc',
        tags: ['Flutter', 'Firebase', 'Slide', 'BLoC', 'Mobile'],
        status: DocumentStatus.completed,
        priority: PriorityLevel.high,
        isFavorite: true,
        latitude: tluLat,
        longitude: tluLng,
        locationName: 'Thư viện ĐH Thủy Lợi - Tầng 2, Kệ C-12',
        isPhysical: true,
        createdDate: now.subtract(const Duration(days: 3)),
        updatedDate: now.subtract(const Duration(days: 3)),
      ),
      DocumentModel(
        id: 'doc_2',
        title: 'Bài tập Lớn TH2: Hệ thống Quản lý Tài liệu Đa nền tảng',
        subjectId: 'sub_mob',
        type: DocumentType.assignment,
        notes:
            'Yêu cầu đáp ứng 6 checklist: Kiến trúc Firebase+Supabase, UI đa nền tảng, Tagging+Location, '
            'Borrow/Share, Recommendation, Kiểm thử & Đóng gói. Hạn nộp cuối kỳ.',
        fileUrl: 'https://classroom.google.com/c/assignment-th2-multiplatform',
        tags: ['TH2', 'Flutter', 'Bài tập lớn', 'Firebase', 'Supabase'],
        status: DocumentStatus.inProgress,
        priority: PriorityLevel.high,
        isFavorite: true,
        deadline: now.add(const Duration(days: 5)),
        latitude: tluLat + 0.0003,
        longitude: tluLng + 0.0005,
        locationName: 'Giảng đường T35 - ĐH Thủy Lợi',
        isPhysical: false,
        createdDate: now.subtract(const Duration(days: 1)),
        updatedDate: now,
      ),
      DocumentModel(
        id: 'doc_3',
        title: 'Giáo trình: Firebase & Supabase cho Ứng dụng Di động',
        subjectId: 'sub_swe',
        type: DocumentType.reference,
        notes:
            'Sách tham khảo chính thức về tích hợp Firebase Authentication/Messaging, '
            'Supabase PostgreSQL, RLS và Storage trong dự án Flutter thực tế.',
        fileUrl: 'https://supabase.com/docs/guides/getting-started',
        tags: ['Firebase', 'Supabase', 'GiaoTrinh', 'Database', 'Tham khảo'],
        status: DocumentStatus.pending,
        priority: PriorityLevel.medium,
        isFavorite: false,
        latitude: tluLat - 0.0005,
        longitude: tluLng - 0.0003,
        locationName: 'Nhà A1 - ĐH Thủy Lợi (Phòng đọc sách)',
        isPhysical: true,
        createdDate: now.subtract(const Duration(days: 5)),
        updatedDate: now.subtract(const Duration(days: 5)),
      ),
      DocumentModel(
        id: 'doc_4',
        title: 'Đề thi Cuối kỳ mẫu: Cấu trúc Dữ liệu & Giải thuật',
        subjectId: 'sub_dsa',
        type: DocumentType.exam,
        notes:
            'Đề thi mẫu trọng tâm thuật toán đồ thị Dijkstra, Cây AVL, Quy hoạch động. '
            'Bản in sẵn lưu tại Văn phòng Khoa CNTT.',
        fileUrl: 'assets/docs/dsa_final_exam_review.pdf',
        tags: ['DeThi', 'Ôn tập', 'DSA', 'Giải thuật'],
        status: DocumentStatus.pending,
        priority: PriorityLevel.high,
        isFavorite: false,
        deadline: now.add(const Duration(days: 12)),
        latitude: tluLat + 0.0008,
        longitude: tluLng - 0.0006,
        locationName: 'Văn phòng Khoa CNTT - ĐH Thủy Lợi',
        isPhysical: true,
        createdDate: now.subtract(const Duration(days: 2)),
        updatedDate: now.subtract(const Duration(days: 2)),
      ),
      DocumentModel(
        id: 'doc_5',
        title: 'Slide Chuyên đề: AI & Recommendation System trong Ứng dụng',
        subjectId: 'sub_swe',
        type: DocumentType.lecture,
        notes:
            'Slide giới thiệu thuật toán gợi ý nội dung (Content-based Filtering, Collaborative Filtering) '
            'áp dụng trong hệ thống quản lý tài liệu TH2.',
        fileUrl: 'https://developers.google.com/machine-learning/recommendation',
        tags: ['AI', 'Recommendation', 'Slide', 'Machine Learning', 'Flutter'],
        status: DocumentStatus.completed,
        priority: PriorityLevel.medium,
        isFavorite: true,
        latitude: tluLat + 0.0002,
        longitude: tluLng + 0.0010,
        locationName: 'Phòng máy tính - Nhà A4, ĐH Thủy Lợi',
        isPhysical: false,
        createdDate: now.subtract(const Duration(days: 7)),
        updatedDate: now.subtract(const Duration(days: 4)),
      ),
    ];
  }

  Database get db {
    if (_db == null) {
      throw StateError(
        'Cơ sở dữ liệu chưa được khởi tạo. Hãy gọi AppDatabase.init() trước.',
      );
    }
    return _db!;
  }

  // ===================================================================
  // CÁC THAO TÁC CỐT LÕI (CRUD OPERATIONS) CHO TÀI LIỆU HỌC TẬP
  // ===================================================================

  /// [CHỨC NĂNG 1] Thêm tài liệu mới (Create)
  Future<int> insertDocument(DocumentModel document) async {
    if (await getSubjectById(document.subjectId) == null) {
      throw StateError(
        'Không thể lưu tài liệu vào môn học không thuộc tài khoản này.',
      );
    }

    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == document.id);
      if (index >= 0) {
        if (_memoryDocumentOwners[index] != _activeOwnerId ||
            _memoryDocuments[index].isShared) {
          throw StateError(
            'ID tài liệu đã được sử dụng bởi một tài khoản khác.',
          );
        }
        _memoryDocuments[index] = document;
      } else {
        _memoryDocuments.insert(0, document);
        _memoryDocumentOwners.insert(0, _activeOwnerId);
      }
      await notifyDocumentsChanged();
      return 1;
    }

    final result = await db.insert(DocumentTable.tableName, {
      ...document.toMap(),
      DocumentTable.colOwnerId: _activeOwnerId,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    await notifyDocumentsChanged();
    return result;
  }

  /// [CHỨC NĂNG 2] Cập nhật tài liệu (Update)
  Future<int> updateDocument(DocumentModel document) async {
    final existing = await getDocumentById(document.id);
    if (existing == null || existing.isShared || !await canEditDocument(document.id)) {
      return 0;
    }
    if (document.subjectId != existing.subjectId &&
        await getSubjectById(document.subjectId) == null) {
      throw StateError(
        'Không thể lưu tài liệu vào môn học không thuộc tài khoản này.',
      );
    }

    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == document.id);
      if (index >= 0) {
        _memoryDocuments[index] = document;
        await notifyDocumentsChanged();
        return 1;
      }
      return 0;
    }

    final result = await db.update(
      DocumentTable.tableName,
      document.toMap(),
      where: '${DocumentTable.colId} = ?',
      whereArgs: [document.id],
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// [CHỨC NĂNG 3] Xóa tài liệu theo ID (Delete)
  Future<int> deleteDocument(String id) async {
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == id);
      if (index < 0 ||
          _memoryDocumentOwners[index] != _activeOwnerId ||
          _memoryDocuments[index].isShared) {
        return 0;
      }
      _memoryDocuments.removeAt(index);
      _memoryDocumentOwners.removeAt(index);
      await notifyDocumentsChanged();
      return 1;
    }

    final existing = await getDocumentById(id);
    if (existing == null || existing.isShared) return 0;
    final result = await db.delete(
      DocumentTable.tableName,
      where: '${DocumentTable.colId} = ? AND ${DocumentTable.colOwnerId} = ?',
      whereArgs: [id, _activeOwnerId],
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// Lấy chi tiết tài liệu theo ID
  Future<DocumentModel?> getDocumentById(String id) async {
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == id);
      if (index < 0) return null;
      final ownerId = _memoryDocumentOwners[index];
      if (ownerId == _activeOwnerId ||
          ownerId == sharedOwnerId ||
          _memoryPermissions.any(
            (permission) =>
                permission.documentId == id &&
                permission.sharedWithUserId == _activeOwnerId,
          )) {
        return _memoryDocuments[index];
      }
      return null;
    }

    final results = await db.query(
      DocumentTable.tableName,
      where: '''${DocumentTable.colId} = ? AND (
        ${DocumentTable.colOwnerId} IN (?, ?) OR EXISTS (
          SELECT 1 FROM ${DocumentPermissionTable.tableName} p
          WHERE p.document_id = ${DocumentTable.tableName}.${DocumentTable.colId}
            AND p.shared_with_user_id = ?
        )
      )''',
      whereArgs: [id, _activeOwnerId, sharedOwnerId, _activeOwnerId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return DocumentModel.fromMap(results.first);
  }

  Future<String?> getDocumentOwnerId(String id) async {
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((document) => document.id == id);
      return index < 0 ? null : _memoryDocumentOwners[index];
    }
    final rows = await db.query(
      DocumentTable.tableName,
      columns: [DocumentTable.colOwnerId],
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[DocumentTable.colOwnerId] as String;
  }

  Future<DocumentPermission?> getPermissionForCurrentUser(
    String documentId,
  ) async {
    if (_useMemoryFallback) {
      for (final permission in _memoryPermissions) {
        if (permission.documentId == documentId &&
            permission.sharedWithUserId == _activeOwnerId) {
          return permission;
        }
      }
      return null;
    }
    final rows = await db.query(
      DocumentPermissionTable.tableName,
      where: 'document_id = ? AND shared_with_user_id = ?',
      whereArgs: [documentId, _activeOwnerId],
      limit: 1,
    );
    return rows.isEmpty ? null : DocumentPermission.fromMap(rows.first);
  }

  Future<List<DocumentPermission>> getDocumentPermissions(
    String documentId,
  ) async {
    if (_useMemoryFallback) {
      return _memoryPermissions
          .where((permission) => permission.documentId == documentId)
          .toList();
    }
    final rows = await db.query(
      DocumentPermissionTable.tableName,
      where: 'document_id = ? AND owner_id = ?',
      whereArgs: [documentId, _activeOwnerId],
      orderBy: 'created_at',
    );
    return rows.map(DocumentPermission.fromMap).toList();
  }

  Future<bool> canManageSharing(String documentId) async {
    final document = await getDocumentById(documentId);
    return document != null &&
        !document.isShared &&
        await getDocumentOwnerId(documentId) == _activeOwnerId;
  }

  Future<bool> canEditDocument(String documentId) async {
    if (await getDocumentOwnerId(documentId) == _activeOwnerId) return true;
    final permission = await getPermissionForCurrentUser(documentId);
    return permission?.role == DocumentPermissionRole.editor;
  }

  Future<void> shareDocument({
    required String documentId,
    required String targetUserId,
    required DocumentPermissionRole role,
  }) async {
    if (targetUserId.trim().isEmpty) {
      throw ArgumentError('Mã tài khoản nhận chia sẻ không được để trống.');
    }
    if (!await canManageSharing(documentId)) {
      throw StateError('Chỉ chủ sở hữu mới có thể quản lý quyền chia sẻ.');
    }
    if (targetUserId.trim() == _activeOwnerId) {
      throw ArgumentError('Không thể chia sẻ tài liệu cho chính tài khoản này.');
    }
    final permission = DocumentPermission(
      documentId: documentId,
      ownerId: _activeOwnerId,
      sharedWithUserId: targetUserId.trim(),
      role: role,
      createdAt: DateTime.now(),
    );
    if (_useMemoryFallback) {
      _memoryPermissions.removeWhere(
        (current) =>
            current.documentId == documentId &&
            current.sharedWithUserId == targetUserId.trim(),
      );
      _memoryPermissions.add(permission);
      await notifyDocumentsChanged();
      return;
    }
    await db.insert(
      DocumentPermissionTable.tableName,
      permission.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await notifyDocumentsChanged();
  }

  Future<void> revokeDocumentShare({
    required String documentId,
    required String targetUserId,
  }) async {
    if (!await canManageSharing(documentId)) {
      throw StateError('Chỉ chủ sở hữu mới có thể quản lý quyền chia sẻ.');
    }
    if (_useMemoryFallback) {
      _memoryPermissions.removeWhere(
        (permission) =>
            permission.documentId == documentId &&
            permission.sharedWithUserId == targetUserId,
      );
      await notifyDocumentsChanged();
      return;
    }
    await db.delete(
      DocumentPermissionTable.tableName,
      where: 'document_id = ? AND owner_id = ? AND shared_with_user_id = ?',
      whereArgs: [documentId, _activeOwnerId, targetUserId],
    );
    await notifyDocumentsChanged();
  }

  /// Lấy toàn bộ danh sách tài liệu
  ///
  /// [includeDeleted] = true để lấy cả các bản ghi đã đánh dấu xóa mềm
  /// (dùng cho tầng đồng bộ). Mặc định ẩn các bản ghi đã xóa khỏi UI.
  Future<List<DocumentModel>> getAllDocuments({bool includeDeleted = false}) async {
    if (_useMemoryFallback) {
      final list = <DocumentModel>[
        for (var i = 0; i < _memoryDocuments.length; i++)
          if ((_memoryDocumentOwners[i] == _activeOwnerId ||
                  _memoryDocumentOwners[i] == sharedOwnerId ||
                  _memoryPermissions.any(
                    (permission) =>
                        permission.documentId == _memoryDocuments[i].id &&
                        permission.sharedWithUserId == _activeOwnerId,
                  )) &&
              (includeDeleted || !_memoryDocuments[i].isDeleted))
            _memoryDocuments[i],
      ];

      list.sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }

    final results = await db.query(
      DocumentTable.tableName,
      where: '''${includeDeleted ? '1 = 1' : '${DocumentTable.colIsDeleted} = 0'} AND (
        ${DocumentTable.colOwnerId} IN (?, ?) OR EXISTS (
          SELECT 1 FROM ${DocumentPermissionTable.tableName} p
          WHERE p.document_id = ${DocumentTable.tableName}.${DocumentTable.colId}
            AND p.shared_with_user_id = ?
        )
      )''',
      whereArgs: [_activeOwnerId, sharedOwnerId, _activeOwnerId],
      orderBy: '${DocumentTable.colUpdatedDate} DESC',
    );
    return results.map((row) => DocumentModel.fromMap(row)).toList();
  }

  /// [CHỨC NĂNG 4] Tìm kiếm tài liệu học tập theo từ khóa, môn học, phân loại
  Future<List<DocumentModel>> searchDocuments({
    String query = '',
    String? subjectId,
    DocumentType? type,
    bool? onlyFavorite,
  }) async {
    if (_useMemoryFallback) {

      var list = <DocumentModel>[
        for (var i = 0; i < _memoryDocuments.length; i++)
          if ((_memoryDocumentOwners[i] == _activeOwnerId ||
                  _memoryDocumentOwners[i] == sharedOwnerId ||
                  _memoryPermissions.any(
                    (permission) =>
                        permission.documentId == _memoryDocuments[i].id &&
                        permission.sharedWithUserId == _activeOwnerId,
                  )) &&
              !_memoryDocuments[i].isDeleted)
            _memoryDocuments[i],
      ];

      final trimmed = query.trim().toLowerCase();
      if (trimmed.isNotEmpty) {
        list = list.where((d) {
          final mTitle = d.title.toLowerCase().contains(trimmed);
          final mNotes = d.notes.toLowerCase().contains(trimmed);
          final mTags = d.tags.any((t) => t.toLowerCase().contains(trimmed));
          return mTitle || mNotes || mTags;
        }).toList();
      }
      if (subjectId != null && subjectId.isNotEmpty) {
        list = list.where((d) => d.subjectId == subjectId).toList();
      }
      if (type != null) {
        list = list.where((d) => d.type == type).toList();
      }
      if (onlyFavorite == true) {
        list = list.where((d) => d.isFavorite).toList();
      }
      list.sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }


    final conditions = <String>[
      '${DocumentTable.colIsDeleted} = 0',
      '''(${DocumentTable.colOwnerId} IN (?, ?) OR EXISTS (
        SELECT 1 FROM ${DocumentPermissionTable.tableName} p
        WHERE p.document_id = ${DocumentTable.tableName}.${DocumentTable.colId}
          AND p.shared_with_user_id = ?
      ))''',
    ];
    final args = <dynamic>[_activeOwnerId, sharedOwnerId, _activeOwnerId];


    final trimmed = query.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      conditions.add(
        '(${DocumentTable.colTitle} LIKE ? OR ${DocumentTable.colNotes} LIKE ? OR ${DocumentTable.colTags} LIKE ?)',
      );
      args.addAll(['%$trimmed%', '%$trimmed%', '%$trimmed%']);
    }

    if (subjectId != null && subjectId.isNotEmpty) {
      conditions.add('${DocumentTable.colSubjectId} = ?');
      args.add(subjectId);
    }

    if (type != null) {
      conditions.add('${DocumentTable.colType} = ?');
      args.add(type.nameString);
    }

    if (onlyFavorite == true) {
      conditions.add('${DocumentTable.colIsFavorite} = 1');
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final results = await db.query(
      DocumentTable.tableName,
      where: whereClause,
      whereArgs: args,
      orderBy: '${DocumentTable.colUpdatedDate} DESC',
    );

    return results.map((row) => DocumentModel.fromMap(row)).toList();
  }

  // ===================================================================
  // CÁC THAO TÁC CHO MÔN HỌC (SUBJECTS)
  // ===================================================================

  Future<int> insertSubject(SubjectModel subject) async {
    if (_useMemoryFallback) {
      final index = _memorySubjects.indexWhere((s) => s.id == subject.id);
      if (index >= 0) {
        if (_memorySubjectOwners[index] != _activeOwnerId) {
          throw StateError(
            'ID môn học đã được sử dụng bởi một tài khoản khác.',
          );
        }
        _memorySubjects[index] = subject;
      } else {
        _memorySubjects.add(subject);
        _memorySubjectOwners.add(_activeOwnerId);
      }
      await notifySubjectsChanged();
      return 1;
    }

    final result = await db.insert(SubjectTable.tableName, {
      ...subject.toMap(),
      SubjectTable.colOwnerId: _activeOwnerId,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    await notifySubjectsChanged();
    return result;
  }

  Future<List<SubjectModel>> getAllSubjects() async {
    if (_useMemoryFallback) {
      final list = [
        for (var i = 0; i < _memorySubjects.length; i++)
          if (_memorySubjectOwners[i] == _activeOwnerId ||
              _memorySubjectOwners[i] == sharedOwnerId ||
              _memoryDocuments.asMap().entries.any(
                (entry) =>
                    entry.value.subjectId == _memorySubjects[i].id &&
                    _memoryPermissions.any(
                      (permission) =>
                          permission.documentId == entry.value.id &&
                          permission.sharedWithUserId == _activeOwnerId,
                    ),
              ))
            _memorySubjects[i],
      ];
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }

    final results = await db.query(
      SubjectTable.tableName,
      where: '''${SubjectTable.colOwnerId} IN (?, ?) OR EXISTS (
        SELECT 1 FROM ${DocumentTable.tableName} d
        JOIN ${DocumentPermissionTable.tableName} p
          ON p.document_id = d.${DocumentTable.colId}
        WHERE d.${DocumentTable.colSubjectId} = ${SubjectTable.tableName}.${SubjectTable.colId}
          AND p.shared_with_user_id = ?
      )''',
      whereArgs: [_activeOwnerId, sharedOwnerId, _activeOwnerId],
      orderBy: '${SubjectTable.colName} ASC',
    );
    return results.map((row) => SubjectModel.fromMap(row)).toList();
  }

  Future<SubjectModel?> getSubjectById(String id) async {
    if (_useMemoryFallback) {
      final index = _memorySubjects.indexWhere((s) => s.id == id);
      if (index < 0) return null;
      final isSharedWithCurrentUser = _memoryDocuments.asMap().entries.any(
        (entry) =>
            entry.value.subjectId == id &&
            _memoryPermissions.any(
              (permission) =>
                  permission.documentId == entry.value.id &&
                  permission.sharedWithUserId == _activeOwnerId,
            ),
      );
      return _memorySubjectOwners[index] == _activeOwnerId ||
              _memorySubjectOwners[index] == sharedOwnerId ||
              isSharedWithCurrentUser
          ? _memorySubjects[index]
          : null;
    }

    final results = await db.query(
      SubjectTable.tableName,
      where: '''${SubjectTable.colId} = ? AND (
        ${SubjectTable.colOwnerId} IN (?, ?) OR EXISTS (
          SELECT 1 FROM ${DocumentTable.tableName} d
          JOIN ${DocumentPermissionTable.tableName} p
            ON p.document_id = d.${DocumentTable.colId}
          WHERE d.${DocumentTable.colSubjectId} = ${SubjectTable.tableName}.${SubjectTable.colId}
            AND p.shared_with_user_id = ?
        )
      )''',
      whereArgs: [id, _activeOwnerId, sharedOwnerId, _activeOwnerId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SubjectModel.fromMap(results.first);
  }

  // ===================================================================
  // CÁC THAO TÁC PHỤC VỤ ĐỒNG BỘ OFFLINE-FIRST (SYNC DAO)
  // ===================================================================

  /// Cập nhật trạng thái đồng bộ và metadata Cloud cho một tài liệu.
  Future<void> markDocumentSyncStatus(
    String id, {
    required SyncStatus syncStatus,
    int? version,
    DateTime? remoteUpdatedAt,
    DateTime? lastSyncedAt,
    String? checksum,
    String? checksumAlgorithm,
    String? storagePath,
    String? localPath,
  }) async {
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == id);
      if (index < 0) return;
      final current = _memoryDocuments[index];
      _memoryDocuments[index] = current.copyWith(
        syncStatus: syncStatus,
        version: version,
        remoteUpdatedAt: remoteUpdatedAt,
        lastSyncedAt: lastSyncedAt,
        checksum: checksum,
        checksumAlgorithm: checksumAlgorithm,
        storagePath: storagePath,
        localPath: localPath,
        updatedDate: current.updatedDate,
      );
      await notifyDocumentsChanged();
      return;
    }

    final values = <String, dynamic>{'sync_status': syncStatus.nameString};
    if (version != null) values[DocumentTable.colVersion] = version;
    if (remoteUpdatedAt != null) {
      values[DocumentTable.colRemoteUpdatedAt] =
          remoteUpdatedAt.millisecondsSinceEpoch;
    }
    if (lastSyncedAt != null) {
      values[DocumentTable.colLastSyncedAt] =
          lastSyncedAt.millisecondsSinceEpoch;
    }
    if (checksum != null) values[DocumentTable.colChecksum] = checksum;
    if (checksumAlgorithm != null) {
      values[DocumentTable.colChecksumAlgo] = checksumAlgorithm;
    }
    if (storagePath != null) values[DocumentTable.colStoragePath] = storagePath;
    if (localPath != null) values[DocumentTable.colLocalPath] = localPath;

    await db.update(
      DocumentTable.tableName,
      values,
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
    );
    await notifyDocumentsChanged();
  }

  /// Xóa cứng một tài liệu khỏi bảng documents (sau khi đã ghi tombstone).
  Future<int> hardDeleteDocument(String id) {
    if (_useMemoryFallback) {
      _memoryDocuments.removeWhere((d) => d.id == id);
      return Future.value(1);
    }
    return db.delete(
      DocumentTable.tableName,
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
    );
  }

  // ---------------------- Bảng delete_logs ----------------------

  /// Thêm hoặc cập nhật một bản ghi tombstone trong `delete_logs`.
  Future<int> insertDeleteLog(DeleteLogModel log) async {
    if (_useMemoryFallback) {
      _memoryDeleteLogs.removeWhere((l) => l.id == log.id);
      _memoryDeleteLogs.add(log);
      return 1;
    }
    return db.insert(
      DeleteLogTable.tableName,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy danh sách delete_logs, có thể lọc theo trạng thái đồng bộ.
  Future<List<DeleteLogModel>> getDeleteLogs({DeleteLogStatus? syncStatus}) async {
    if (_useMemoryFallback) {
      final list = _memoryDeleteLogs
          .where((l) => syncStatus == null || l.syncStatus == syncStatus)
          .toList()
        ..sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
      return list;
    }
    final results = await db.query(
      DeleteLogTable.tableName,
      where: syncStatus == null
          ? null
          : '${DeleteLogTable.colSyncStatus} = ?',
      whereArgs: syncStatus == null ? null : [syncStatus.nameString],
      orderBy: '${DeleteLogTable.colDeletedAt} ASC',
    );
    return results.map((row) => DeleteLogModel.fromMap(row)).toList();
  }

  /// Cập nhật trạng thái đồng bộ của một delete_log.
  Future<void> updateDeleteLogStatus(
    String id,
    DeleteLogStatus status, {
    String? lastError,
    DateTime? remoteUpdatedAt,
  }) async {
    if (_useMemoryFallback) {
      final index = _memoryDeleteLogs.indexWhere((l) => l.id == id);
      if (index < 0) return;
      final current = _memoryDeleteLogs[index];
      _memoryDeleteLogs[index] = current.copyWith(
        syncStatus: status,
        lastError: lastError,
        remoteUpdatedAt: remoteUpdatedAt,
      );
      return;
    }
    final values = <String, dynamic>{
      DeleteLogTable.colSyncStatus: status.nameString,
    };
    if (lastError != null) values[DeleteLogTable.colLastError] = lastError;
    if (remoteUpdatedAt != null) {
      values[DeleteLogTable.colRemoteUpdatedAt] =
          remoteUpdatedAt.millisecondsSinceEpoch;
    }
    await db.update(
      DeleteLogTable.tableName,
      values,
      where: '${DeleteLogTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Tăng số lần thử lại của một delete_log khi đồng bộ thất bại.
  Future<void> incrementDeleteLogRetry(String id, String error) async {
    if (_useMemoryFallback) {
      final index = _memoryDeleteLogs.indexWhere((l) => l.id == id);
      if (index < 0) return;
      final current = _memoryDeleteLogs[index];
      _memoryDeleteLogs[index] = current.copyWith(
        retryCount: current.retryCount + 1,
        lastError: error,
        syncStatus: DeleteLogStatus.failed,
      );
      return;
    }
    await db.rawUpdate(
      'UPDATE ${DeleteLogTable.tableName} '
      'SET ${DeleteLogTable.colRetryCount} = ${DeleteLogTable.colRetryCount} + 1, '
      '${DeleteLogTable.colLastError} = ?, '
      '${DeleteLogTable.colSyncStatus} = ? '
      'WHERE ${DeleteLogTable.colId} = ?',
      [error, DeleteLogStatus.failed.nameString, id],
    );
  }

  // ---------------------- Bảng sync_outbox ----------------------

  /// Đưa một thao tác cục bộ vào hàng đợi đồng bộ.
  Future<String> enqueueOutbox({
    required String entityId,
    required SyncOperation operation,
    String entityType = 'document',
    Map<String, dynamic>? payload,
  }) async {
    final entry = SyncOutboxEntry(
      id: const Uuid().v4(),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: DateTime.now(),
    );
    if (_useMemoryFallback) {
      _memoryOutbox.add(entry);
      return entry.id;
    }
    await db.insert(
      SyncOutboxTable.tableName,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return entry.id;
  }

  /// Lấy danh sách các thao tác đang chờ đồng bộ (FIFO).
  Future<List<SyncOutboxEntry>> getOutboxEntries({int limit = 200}) async {
    if (_useMemoryFallback) {
      final list = List<SyncOutboxEntry>.from(_memoryOutbox)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list.take(limit).toList();
    }
    final results = await db.query(
      SyncOutboxTable.tableName,
      orderBy: '${SyncOutboxTable.colCreatedAt} ASC',
      limit: limit,
    );
    return results.map((row) => SyncOutboxEntry.fromMap(row)).toList();
  }

  /// Xóa một thao tác khỏi hàng đợi sau khi đồng bộ thành công.
  Future<void> removeOutboxEntry(String id) async {
    if (_useMemoryFallback) {
      _memoryOutbox.removeWhere((e) => e.id == id);
      return;
    }
    await db.delete(
      SyncOutboxTable.tableName,
      where: '${SyncOutboxTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Tăng số lần thử lại và ghi nhận lỗi cho một thao tác đồng bộ.
  Future<void> incrementOutboxRetry(String id, String error) async {
    if (_useMemoryFallback) {
      final index = _memoryOutbox.indexWhere((e) => e.id == id);
      if (index < 0) return;
      final current = _memoryOutbox[index];
      _memoryOutbox[index] = SyncOutboxEntry(
        id: current.id,
        entityType: current.entityType,
        entityId: current.entityId,
        operation: current.operation,
        payload: current.payload,
        createdAt: current.createdAt,
        retryCount: current.retryCount + 1,
        lastError: error,
      );
      return;
    }
    await db.rawUpdate(
      'UPDATE ${SyncOutboxTable.tableName} '
      'SET ${SyncOutboxTable.colRetryCount} = ${SyncOutboxTable.colRetryCount} + 1, '
      '${SyncOutboxTable.colLastError} = ? '
      'WHERE ${SyncOutboxTable.colId} = ?',
      [error, id],
    );
  }

  /// Số thao tác đang chờ đồng bộ (dùng cho badge UI).
  Future<int> getPendingSyncCount() async {
    if (_useMemoryFallback) return _memoryOutbox.length;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${SyncOutboxTable.tableName}',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  // ---------------------- Bảng sync_state ----------------------

  /// Lấy mốc thời gian đồng bộ gần nhất.
  Future<DateTime?> getLastSyncAt() async {
    if (_useMemoryFallback) {
      final value = _memorySyncState[SyncStateTable.keyLastSyncAt];
      return value == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(value));
    }
    final results = await db.query(
      SyncStateTable.tableName,
      where: '${SyncStateTable.colKey} = ?',
      whereArgs: [SyncStateTable.keyLastSyncAt],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final value = results.first[SyncStateTable.colValue] as String?;
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(value));
  }

  /// Cập nhật mốc thời gian đồng bộ gần nhất.
  Future<void> setLastSyncAt(DateTime value) async {
    final millis = value.millisecondsSinceEpoch.toString();
    if (_useMemoryFallback) {
      _memorySyncState[SyncStateTable.keyLastSyncAt] = millis;
      return;
    }
    await db.insert(
      SyncStateTable.tableName,
      {
        SyncStateTable.colKey: SyncStateTable.keyLastSyncAt,
        SyncStateTable.colValue: millis,
        SyncStateTable.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===================================================================
  // PHẢN ỨNG DỮ LIỆU THEO PHONG CÁCH CASHEW (REACTIVE NOTIFIERS)
  // ===================================================================

  
  // ===================================================================
  // CÁC THAO TÁC CHO MƯỢN / TRẢ TÀI LIỆU (BORROW REQUESTS DAO)
  // ===================================================================

  Future<int> insertBorrowRequest(BorrowRequestModel request) async {
    if (_useMemoryFallback) {
      _memoryBorrowRequests.removeWhere((r) => r.id == request.id);
      _memoryBorrowRequests.insert(0, request);
      await notifyBorrowRequestsChanged();
      return 1;
    }
    final result = await db.insert(
      BorrowRequestTable.tableName,
      request.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await notifyBorrowRequestsChanged();
    return result;
  }

  Future<int> updateBorrowRequest(BorrowRequestModel request) async {
    if (_useMemoryFallback) {
      final index = _memoryBorrowRequests.indexWhere((r) => r.id == request.id);
      if (index >= 0) {
        _memoryBorrowRequests[index] = request;
        await notifyBorrowRequestsChanged();
        return 1;
      }
      return 0;
    }
    final result = await db.update(
      BorrowRequestTable.tableName,
      request.toMap(),
      where: '${BorrowRequestTable.colId} = ?',
      whereArgs: [request.id],
    );
    await notifyBorrowRequestsChanged();
    return result;
  }

  Future<BorrowRequestModel?> getBorrowRequestById(String id) async {
    if (_useMemoryFallback) {
      final index = _memoryBorrowRequests.indexWhere((r) => r.id == id);
      return index >= 0 ? _memoryBorrowRequests[index] : null;
    }
    final rows = await db.query(
      BorrowRequestTable.tableName,
      where: '${BorrowRequestTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BorrowRequestModel.fromMap(rows.first);
  }

  Future<List<BorrowRequestModel>> getBorrowRequestsForBorrower(String borrowerId) async {
    if (_useMemoryFallback) {
      final list = _memoryBorrowRequests
          .where((r) => r.borrowerId == borrowerId)
          .toList()
        ..sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }
    final rows = await db.query(
      BorrowRequestTable.tableName,
      where: '${BorrowRequestTable.colBorrowerId} = ?',
      whereArgs: [borrowerId],
      orderBy: '${BorrowRequestTable.colUpdatedAt} DESC',
    );
    return rows.map(BorrowRequestModel.fromMap).toList();
  }

  Future<List<BorrowRequestModel>> getBorrowRequestsForOwner(String ownerId) async {
    if (_useMemoryFallback) {
      final list = _memoryBorrowRequests
          .where((r) => r.ownerId == ownerId)
          .toList()
        ..sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }
    final rows = await db.query(
      BorrowRequestTable.tableName,
      where: '${BorrowRequestTable.colOwnerId} = ?',
      whereArgs: [ownerId],
      orderBy: '${BorrowRequestTable.colUpdatedAt} DESC',
    );
    return rows.map(BorrowRequestModel.fromMap).toList();
  }

  Future<List<BorrowRequestModel>> getAllBorrowRequests() async {
    if (_useMemoryFallback) {
      final list = List<BorrowRequestModel>.from(_memoryBorrowRequests)
        ..sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }
    final rows = await db.query(
      BorrowRequestTable.tableName,
      orderBy: '${BorrowRequestTable.colUpdatedAt} DESC',
    );
    return rows.map(BorrowRequestModel.fromMap).toList();
  }

  Future<int> deleteBorrowRequest(String id) async {
    if (_useMemoryFallback) {
      _memoryBorrowRequests.removeWhere((r) => r.id == id);
      await notifyBorrowRequestsChanged();
      return 1;
    }
    final result = await db.delete(
      BorrowRequestTable.tableName,
      where: '${BorrowRequestTable.colId} = ?',
      whereArgs: [id],
    );
    await notifyBorrowRequestsChanged();
    return result;
  }

  Future<void> notifyBorrowRequestsChanged() async {
    final all = await getAllBorrowRequests();
    if (!_borrowRequestsStreamController.isClosed) {
      _borrowRequestsStreamController.add(all);
    }
  }

Future<void> notifyDocumentsChanged() async {
    final all = await getAllDocuments();
    _cachedDocuments = all;
    if (!_documentsStreamController.isClosed) {
      _documentsStreamController.add(all);
    }
  }

  Future<void> notifySubjectsChanged() async {
    final all = await getAllSubjects();
    _cachedSubjects = all;
    if (!_subjectsStreamController.isClosed) {
      _subjectsStreamController.add(all);
    }
  }

  Future<void> close() async {
    await _documentsStreamController.close();
    await _subjectsStreamController.close();
    await _borrowRequestsStreamController.close();
    await _db?.close();
  }
}
