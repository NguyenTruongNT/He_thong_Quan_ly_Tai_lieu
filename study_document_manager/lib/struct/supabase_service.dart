// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/struct/supabase_service.dart
// Mô tả: Lớp dịch vụ tích hợp toàn diện với Supabase Cloud:
//   - Xác thực người dùng (Supabase Auth - Email/Google)
//   - Tương tác cơ sở dữ liệu quan hệ (Profiles, Documents, Document Permissions)
//   - Phân quyền & Chia sẻ tài liệu (viewer/editor) với Row Level Security (RLS)
//   - Lưu trữ và tải tệp tin vật lý trên Supabase Storage (Bucket 'documents')
// =====================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../supabase_options.dart';
import 'models/document_models.dart';
import 'models/document_permission.dart';
import 'models/borrow_request_model.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _isInitialized = false;
  SupabaseClient? _client;

  bool get isInitialized => _isInitialized && _client != null;

  SupabaseClient? get client => _client;

  User? get currentUser => client?.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      client != null ? client!.auth.onAuthStateChange : const Stream.empty();

  /// Khởi tạo Supabase Client
  Future<bool> initialize({String? customUrl, String? customAnonKey}) async {
    final rawUrl = customUrl ?? SupabaseOptions.url;
    final url = SupabaseOptions.normalizeUrl(rawUrl);
    final anonKey = (customAnonKey ?? SupabaseOptions.anonKey).trim();

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('[SupabaseService] URL hoặc Anon Key chưa được thiết lập.');
      return false;
    }

    try {
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
      } catch (e) {
        debugPrint('[SupabaseService] Supabase.initialize note: $e');
      }
      try {
        _client = Supabase.instance.client;
      } catch (_) {
        _client = SupabaseClient(url, anonKey);
      }
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Khởi tạo Supabase thất bại: $e');
      return false;
    }
  }

  // ===================================================================
  // 1. XÁC THỰC NGƯỜI DÙNG (SUPABASE AUTH)
  // ===================================================================

  /// Đăng nhập bằng Email và Mật khẩu (100% Miễn phí, không cần thẻ)
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureInitialized();
    return await client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Đăng ký tài khoản mới bằng Email
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _ensureInitialized();
    return await client!.auth.signUp(
      email: email.trim(),
      password: password,
      data: displayName != null ? {'full_name': displayName} : null,
    );
  }

  /// Đăng nhập bằng tài khoản GitHub qua Supabase OAuth
  Future<bool> signInWithGitHub() async {
    _ensureInitialized();
    return await client!.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: kIsWeb ? null : 'io.supabase.cashew://login-callback/',
    );
  }

  /// Đăng xuất khỏi Supabase
  Future<void> signOut() async {
    if (_isInitialized && client != null) {
      await client!.auth.signOut();
    }
  }

  // ===================================================================
  // 2. QUẢN LÝ HỒ SƠ NGƯỜI DÙNG (PROFILES)
  // ===================================================================

  /// Lấy danh sách tất cả người dùng để hiển thị khi tìm kiếm chia sẻ
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    _ensureInitialized();
    try {
      final res = await client!
          .from('profiles')
          .select('id, email, display_name, avatar_url')
          .order('display_name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[SupabaseService] getAllProfiles error: $e');
      return [];
    }
  }

  /// Tìm kiếm người dùng theo Email
  Future<Map<String, dynamic>?> findProfileByEmail(String email) async {
    _ensureInitialized();
    try {
      final res = await client!
          .from('profiles')
          .select('id, email, display_name')
          .ilike('email', email.trim())
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] findProfileByEmail error: $e');
      return null;
    }
  }

  // ===================================================================
  // 3. THAO TÁC DỮ LIỆU TÀI LIỆU (DOCUMENTS CRUD VỚI RLS)
  // ===================================================================

  /// Lấy danh sách tài liệu thuộc quyền truy cập của người dùng (Owner + Shared)
  /// Row Level Security trên Supabase tự động lọc kết quả!
  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    _ensureInitialized();
    final res = await client!
        .from('documents')
        .select()
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Lấy chi tiết tài liệu theo ID
  Future<Map<String, dynamic>?> getDocumentById(String id) async {
    _ensureInitialized();
    final res = await client!
        .from('documents')
        .select()
        .eq('id', id)
        .maybeSingle();
    return res;
  }

  /// Thêm mới tài liệu (Chỉ Owner mới có quyền tạo cho chính mình)
  Future<Map<String, dynamic>> insertDocument(
    Map<String, dynamic> documentData,
  ) async {
    _ensureInitialized();
    final user = currentUser;
    if (user == null) {
      throw StateError('Yêu cầu đăng nhập trước khi tạo tài liệu.');
    }

    final payload = Map<String, dynamic>.from(documentData);
    payload['owner_id'] = user.id;
    payload['created_at'] = DateTime.now().toIso8601String();
    payload['updated_at'] = DateTime.now().toIso8601String();

    final res = await client!.from('documents').insert(payload).select().single();
    return res;
  }

  /// Cập nhật thông tin tài liệu
  /// (RLS cho phép Owner hoặc Editor; Viewer sẽ bị từ chối)
  Future<Map<String, dynamic>> updateDocument(
    String documentId,
    Map<String, dynamic> updates,
  ) async {
    _ensureInitialized();
    final payload = Map<String, dynamic>.from(updates);
    payload['updated_at'] = DateTime.now().toIso8601String();

    final res = await client!
        .from('documents')
        .update(payload)
        .eq('id', documentId)
        .select()
        .single();
    return res;
  }

  /// Xóa tài liệu (RLS CHỈ cho phép Owner xóa; Editor/Viewer bị từ chối)
  Future<void> deleteDocument(String documentId) async {
    _ensureInitialized();
    await client!.from('documents').delete().eq('id', documentId);
  }

  /// Tìm kiếm tài liệu theo từ khóa
  Future<List<Map<String, dynamic>>> searchDocuments(String query) async {
    _ensureInitialized();
    final q = '%$query%';
    final res = await client!
        .from('documents')
        .select()
        .or('title.ilike.$q,notes.ilike.$q,subject.ilike.$q')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // ===================================================================
  // 4. PHÂN QUYỀN VÀ CHIA SẺ TÀI LIỆU (PERMISSIONS)
  // ===================================================================

  /// Lấy danh sách phân quyền của một tài liệu (Viewer / Editor)
  Future<List<Map<String, dynamic>>> getDocumentPermissions(
    String documentId,
  ) async {
    _ensureInitialized();
    final res = await client!
        .from('document_permissions')
        .select('document_id, owner_id, shared_with_user_id, role, created_at')
        .eq('document_id', documentId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Đảm bảo tài liệu đã tồn tại trong bảng documents trên Supabase trước khi tạo permission
  Future<String> ensureDocumentExists(DocumentModel doc) async {
    _ensureInitialized();
    final user = currentUser;
    if (user == null) {
      throw StateError('Yêu cầu đăng nhập Supabase trước khi đồng bộ tài liệu.');
    }

    final validDocId = _uuidPattern.hasMatch(doc.id)
        ? doc.id
        : const Uuid().v5(Uuid.NAMESPACE_URL, 'doc:${doc.id}');

    final existing = await client!
        .from('documents')
        .select('id')
        .eq('id', validDocId)
        .maybeSingle();

    if (existing == null) {
      var title = doc.title.trim();
      if (title.length < 3) title = '$title   ';
      if (title.length > 250) title = title.substring(0, 250);

      var docType = doc.type.name.toLowerCase();
      if (!['lecture', 'assignment', 'reference', 'exam'].contains(docType)) {
        docType = 'lecture';
      }

      await client!.from('documents').upsert({
        'id': validDocId,
        'owner_id': user.id,
        'title': title,
        'subject': doc.subjectId,
        'type': docType,
        'notes': doc.notes,
        'tags': doc.tags,
        'file_path': doc.storagePath,
        'file_url': doc.fileUrl,
        'checksum': doc.checksum,
        'checksum_algo': doc.checksumAlgorithm,
        'version': doc.version,
        'updated_at': doc.updatedDate.toUtc().toIso8601String(),
      });
    }

    return validDocId;
  }

  /// Chia sẻ tài liệu cho người dùng khác qua User ID
  Future<void> shareDocument({
    required String documentId,
    required String targetUserId,
    required DocumentPermissionRole role,
  }) async {
    _ensureInitialized();
    final user = currentUser;
    if (user == null) {
      throw StateError('Yêu cầu đăng nhập trước khi chia sẻ.');
    }

    final validDocId = _uuidPattern.hasMatch(documentId)
        ? documentId
        : const Uuid().v5(Uuid.NAMESPACE_URL, 'doc:$documentId');

    final roleString =
        role == DocumentPermissionRole.editor ? 'editor' : 'viewer';

    await client!.from('document_permissions').upsert({
      'document_id': validDocId,
      'owner_id': user.id,
      'shared_with_user_id': targetUserId,
      'role': roleString,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Chia sẻ tài liệu bằng Email người nhận (qua RPC hoặc tra cứu profile)
  Future<void> shareDocumentByEmail({
    required String documentId,
    required String email,
    required DocumentPermissionRole role,
  }) async {
    _ensureInitialized();
    final validDocId = _uuidPattern.hasMatch(documentId)
        ? documentId
        : const Uuid().v5(Uuid.NAMESPACE_URL, 'doc:$documentId');

    final roleString =
        role == DocumentPermissionRole.editor ? 'editor' : 'viewer';

    try {
      // Thử gọi RPC share_document_by_email nếu đã nạp trong DB
      await client!.rpc('share_document_by_email', params: {
        'p_document_id': validDocId,
        'p_email': email.trim(),
        'p_role': roleString,
      });
    } catch (_) {
      // Fallback: Tìm profile theo email và upsert bảng permissions trực tiếp
      final profile = await findProfileByEmail(email);
      if (profile == null) {
        throw ArgumentError('Không tìm thấy người dùng có email: $email');
      }
      await shareDocument(
        documentId: validDocId,
        targetUserId: profile['id'] as String,
        role: role,
      );
    }
  }

  /// Thu hồi quyền chia sẻ tài liệu
  Future<void> revokeDocumentShare({
    required String documentId,
    required String targetUserId,
  }) async {
    _ensureInitialized();
    final validDocId = _uuidPattern.hasMatch(documentId)
        ? documentId
        : const Uuid().v5(Uuid.NAMESPACE_URL, 'doc:$documentId');

    await client!
        .from('document_permissions')
        .delete()
        .eq('document_id', validDocId)
        .eq('shared_with_user_id', targetUserId);
  }

  // ===================================================================
  // 5. LƯU TRỮ VÀ QUẢN LÝ TỆP (SUPABASE STORAGE BUCKET 'documents')
  // ===================================================================

  /// Tải tệp lên Supabase Storage
  /// Cấu trúc: users/{ownerId}/documents/{documentId}/{fileName}
  Future<String> uploadDocumentFile({
    required String documentId,
    required String fileName,
    required Uint8List fileBytes,
    String? mimeType,
  }) async {
    _ensureInitialized();
    final user = currentUser;
    if (user == null) {
      throw StateError('Đăng nhập trước khi tải tệp lên Storage.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = 'users/${user.id}/documents/$documentId/$safeName';

    await client!.storage.from('documents').uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: FileOptions(
        contentType: mimeType ?? 'application/octet-stream',
        upsert: true,
      ),
    );

    return storagePath;
  }

  /// Lấy URL xem/tải tệp có thời hạn (Signed URL)
  Future<String> createSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    _ensureInitialized();
    return await client!.storage
        .from('documents')
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  /// Tải nội dung tệp nhị phân từ Supabase Storage
  Future<Uint8List> downloadFile(String storagePath) async {
    _ensureInitialized();
    return await client!.storage.from('documents').download(storagePath);
  }

  /// Xóa tệp khỏi Supabase Storage
  Future<void> deleteStorageFile(String storagePath) async {
    _ensureInitialized();
    await client!.storage.from('documents').remove([storagePath]);
  }

  
  // ===================================================================
  // 6. QUẢN LÝ MƯỢN / TRẢ TÀI LIỆU & THÔNG BÁO REALTIME (TH2)
  // ===================================================================

  /// Gửi yêu cầu mượn tài liệu (thông qua Stored Procedure an toàn)
  Future<Map<String, dynamic>> sendBorrowRequest({
    required String documentId,
    DateTime? dueDate,
    String note = '',
  }) async {
    _ensureInitialized();
    final validDocId = _uuidPattern.hasMatch(documentId)
        ? documentId
        : const Uuid().v5(Uuid.NAMESPACE_URL, 'doc:$documentId');

    try {
      final res = await client!.rpc('create_borrow_request', params: {
        'p_document_id': validDocId,
        'p_due_date': dueDate?.toUtc().toIso8601String(),
        'p_note': note,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('[SupabaseService] sendBorrowRequest RPC error: $e. Fallback insert...');
      final user = currentUser;
      if (user == null) throw StateError('Chưa đăng nhập.');

      final doc = await client!
          .from('documents')
          .select('owner_id')
          .eq('id', validDocId)
          .single();
      final ownerId = doc['owner_id'] as String;

      final insertRes = await client!.from('borrow_requests').insert({
        'document_id': validDocId,
        'borrower_id': user.id,
        'borrower_email': user.email ?? '',
        'owner_id': ownerId,
        'status': 'pending',
        'due_date': dueDate?.toUtc().toIso8601String(),
        'note': note,
      }).select().single();
      return Map<String, dynamic>.from(insertRes);
    }
  }

  /// Chủ sở hữu duyệt hoặc từ chối yêu cầu mượn
  Future<void> respondBorrowRequest({
    required String requestId,
    required String action, // 'approved' | 'rejected'
  }) async {
    _ensureInitialized();
    try {
      await client!.rpc('respond_borrow_request', params: {
        'p_request_id': requestId,
        'p_action': action,
      });
    } catch (e) {
      debugPrint('[SupabaseService] respondBorrowRequest RPC error: $e. Fallback update...');
      await client!.from('borrow_requests').update({
        'status': action,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
    }
  }

  /// Đánh dấu tài liệu đã được hoàn trả
  Future<void> markDocumentReturned({required String requestId}) async {
    _ensureInitialized();
    try {
      await client!.rpc('mark_document_returned', params: {
        'p_request_id': requestId,
      });
    } catch (e) {
      debugPrint('[SupabaseService] markDocumentReturned RPC error: $e. Fallback update...');
      await client!.from('borrow_requests').update({
        'status': 'returned',
        'return_date': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
    }
  }

  /// Lấy danh sách yêu cầu mượn liên quan tới người dùng hiện tại
  Future<List<BorrowRequestModel>> getBorrowRequestsForCurrentUser() async {
    _ensureInitialized();
    final user = currentUser;
    if (user == null) return [];

    final rows = await client!
        .from('borrow_requests')
        .select('*, documents(title), profiles!borrower_id(display_name)')
        .or('borrower_id.eq.${user.id},owner_id.eq.${user.id}')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => BorrowRequestModel.fromSupabase(r as Map<String, dynamic>))
        .toList();
  }

  /// Lắng nghe luồng sự kiện Realtime của bảng borrow_requests
  RealtimeChannel? subscribeBorrowRequests({
    required String userId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    if (!isInitialized || client == null) return null;

    final channel = client!.channel('public:borrow_requests_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'borrow_requests',
          callback: (payload) {
            onEvent(payload);
          },
        )
        .subscribe();

    return channel;
  }

  /// Cập nhật danh sách tag yêu thích trong hồ sơ người dùng
  Future<void> updateFavoriteTags(List<String> tags) async {
    _ensureInitialized();
    final user = currentUser;
    if (user == null) return;
    await client!.from('profiles').update({
      'favorite_tags': tags,
    }).eq('id', user.id);
  }

  /// Lấy danh sách tag yêu thích của người dùng
  Future<List<String>> getFavoriteTags([String? userId]) async {
    _ensureInitialized();
    final targetId = userId ?? currentUser?.id;
    if (targetId == null) return [];
    final res = await client!
        .from('profiles')
        .select('favorite_tags')
        .eq('id', targetId)
        .maybeSingle();
    if (res != null && res['favorite_tags'] is List) {
      return (res['favorite_tags'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

void _ensureInitialized() {
    if (!_isInitialized || client == null) {
      throw StateError(
        'Supabase chưa được khởi tạo. Hãy cấu hình Project URL và Anon Key.',
      );
    }
  }
}
