// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/struct/sync/supabase_remote_sync_service.dart
// Mô tả: Triển khai RemoteSyncService sử dụng Supabase PostgreSQL & Storage.
// Cho phép SyncEngine đồng bộ 2 chiều dữ liệu tài liệu và tệp tin thực tế
// lên đám mây Supabase hoàn toàn miễn phí.
// =====================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/borrow_request_model.dart';
import '../supabase_service.dart';
import 'remote_sync_service.dart';

class SupabaseRemoteSyncService implements RemoteSyncService {
  final SupabaseService _service;

  SupabaseRemoteSyncService({SupabaseService? service})
      : _service = service ?? SupabaseService.instance;

  SupabaseClient? get _client => _service.client;

  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<bool> ping() async {
    try {
      if (!_service.isInitialized || _client == null) return false;
      await _client!.from('profiles').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DateTime> serverTime() async {
    return DateTime.now().toUtc();
  }

  @override
  Future<List<RemoteDocument>> pullChanges({
    required String ownerId,
    DateTime? since,
  }) async {
    if (!_service.isInitialized || _client == null) {
      throw const RemoteNetworkException('Supabase chưa sẵn sàng.');
    }

    try {
      var query = _client!.from('documents').select();
      if (since != null) {
        query = query.gte('updated_at', since.toUtc().toIso8601String());
      }

      final rows = await query;
      final results = <RemoteDocument>[];

      for (final row in rows) {
        final updatedAt =
            DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                DateTime.now();
        final id = row['id'].toString();
        final docOwnerId = row['owner_id'].toString();
        final version = (row['version'] as num?)?.toInt() ?? 1;

        // Chuẩn hóa dữ liệu sang format phù hợp với DocumentModel.fromMap
        final tagsValue = row['tags'];
        final tagsString = tagsValue is List
            ? tagsValue.join(', ')
            : (tagsValue?.toString() ?? '');

        final createdAtDate =
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                updatedAt;

        final localCompatibleData = <String, dynamic>{
          'id': id,
          'title': row['title'] ?? '',
          'subject_id': (row['subject']?.toString().isNotEmpty ?? false)
              ? row['subject']
              : 'sub_swe',
          'type': row['type'] ?? 'lecture',
          'notes': row['notes'] ?? '',
          'tags': tagsString,
          'file_url': row['file_url'] ?? '',
          'storage_path': row['file_path'],
          'checksum': row['checksum'],
          'checksum_algo': row['checksum_algo'] ?? 'sha256',
          'version': version,
          'priority': 'medium',
          'is_favorite': 0,
          'created_date': createdAtDate.millisecondsSinceEpoch,
          'updated_date': updatedAt.millisecondsSinceEpoch,
          'latitude': (row['latitude'] as num?)?.toDouble(),
          'longitude': (row['longitude'] as num?)?.toDouble(),
          'location_name': row['location_name']?.toString(),
          'is_physical': (row['is_physical'] == true || row['is_physical'] == 1) ? 1 : 0,
        };

        results.add(
          RemoteDocument(
            id: id,
            ownerId: docOwnerId,
            version: version,
            updatedAt: updatedAt,
            data: localCompatibleData,
            isDeleted: false,
            checksum: row['checksum']?.toString(),
            checksumAlgorithm:
                row['checksum_algo']?.toString() ?? 'sha256',
            storagePath: row['file_path']?.toString(),
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] pullChanges error: $e');
      throw RemoteNetworkException('Lỗi kéo dữ liệu từ Supabase: $e');
    }
  }

  @override
  Future<RemoteDocument> pushDocument(RemoteDocument document) async {
    if (!_service.isInitialized || _client == null) {
      throw const RemoteNetworkException('Supabase chưa kết nối.');
    }

    try {
      final user = _service.currentUser;
      if (user == null) {
        throw const RemoteNetworkException(
          'Chưa đăng nhập Supabase Cloud. Vui lòng đăng nhập để đồng bộ.',
        );
      }

      final docData = Map<String, dynamic>.from(document.data);

      // Đảm bảo ID là UUID hợp lệ cho bảng Supabase
      final docId = document.id;
      final validId = _uuidPattern.hasMatch(docId)
          ? docId
          : _uuid.v5(Uuid.NAMESPACE_URL, 'doc:$docId');

      // Chuẩn hóa tags thành PostgreSQL text[] (List<String>)
      final rawTags = docData['tags'];
      final List<String> tagsList = rawTags is List
          ? rawTags.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : (rawTags?.toString() ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      var docType = (docData['type'] ?? 'lecture').toString().toLowerCase();
      if (!['lecture', 'assignment', 'reference', 'exam'].contains(docType)) {
        docType = 'lecture';
      }

      var title = (docData['title'] ?? 'Tài liệu học tập').toString().trim();
      if (title.length < 3) title = '$title   ';
      if (title.length > 250) title = title.substring(0, 250);

      // LỌC CHỈ GỬI CÁC CỘT CÓ THẬT TRONG BẢNG DOCUMENTS CỦA SUPABASE:
      // (Không gửi subject_id, status, priority, deadline, is_favorite, v.v. của SQLite)
      final cleanPayload = <String, dynamic>{
        'id': validId,
        'owner_id': user.id, // Luôn dùng UUID của user đang đăng nhập (RLS auth.uid())
        'title': title,
        'subject': (docData['subject'] ?? docData['subject_name'] ?? docData['subject_id'] ?? '').toString(),
        'type': docType,
        'notes': (docData['notes'] ?? '').toString(),
        'tags': tagsList,
        'file_path': document.storagePath ?? docData['file_path'] ?? docData['storage_path'],
        'file_url': docData['file_url']?.toString(),
        'checksum': document.checksum ?? docData['checksum']?.toString(),
        'checksum_algo': document.checksumAlgorithm,
        'version': document.version,
        'updated_at': document.updatedAt.toUtc().toIso8601String(),
        'latitude': docData['latitude'] != null
            ? (docData['latitude'] as num).toDouble()
            : null,
        'longitude': docData['longitude'] != null
            ? (docData['longitude'] as num).toDouble()
            : null,
        'location_name': docData['location_name']?.toString(),
        'is_physical': (docData['is_physical'] == 1 || docData['is_physical'] == true),
      };

      // Kiểm tra xung đột phiên bản nếu tài liệu đã tồn tại
      final existing = await _client!
          .from('documents')
          .select('version')
          .eq('id', validId)
          .maybeSingle();

      if (existing != null) {
        final remoteVersion = (existing['version'] as num?)?.toInt() ?? 1;
        if (remoteVersion > document.version) {
          throw RemoteConflictException(document.copyWith(version: remoteVersion));
        }
      }

      final res = await _client!
          .from('documents')
          .upsert(cleanPayload)
          .select()
          .single();

      final updatedDate =
          DateTime.tryParse(res['updated_at']?.toString() ?? '') ??
              document.updatedAt;

      return document.copyWith(
        version: (res['version'] as num?)?.toInt() ?? document.version,
        updatedAt: updatedDate,
      );
    } on RemoteConflictException {
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] pushDocument error: $e');
      throw RemoteNetworkException('Không thể đẩy tài liệu lên Supabase: $e');
    }
  }

  @override
  Future<void> deleteRemoteDocument({
    required String ownerId,
    required String documentId,
    String? storagePath,
  }) async {
    if (!_service.isInitialized || _client == null) return;

    try {
      if (storagePath != null && storagePath.isNotEmpty) {
        await deleteFile(storagePath: storagePath);
      }
      final validId = _uuidPattern.hasMatch(documentId)
          ? documentId
          : _uuid.v5(Uuid.NAMESPACE_URL, 'doc:$documentId');

      await _client!.from('documents').delete().eq('id', validId);
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] delete error: $e');
    }
  }

  @override
  Future<String> uploadFile({
    required String ownerId,
    required String documentId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    if (!_service.isInitialized || _client == null) {
      throw const RemoteNetworkException('Supabase chưa kết nối.');
    }

    try {
      onProgress?.call(0.2);
      final user = _service.currentUser;
      final targetOwnerId = user?.id ?? ownerId;
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = 'users/$targetOwnerId/documents/$documentId/$safeName';

      await _client!.storage.from('documents').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true),
      );
      onProgress?.call(1.0);
      return path;
    } catch (e) {
      throw RemoteNetworkException('Tải tệp lên Supabase Storage thất bại: $e');
    }
  }

  @override
  Future<List<int>?> downloadFile({
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    if (!_service.isInitialized || _client == null) return null;

    try {
      onProgress?.call(0.2);
      final bytes = await _client!.storage
          .from('documents')
          .download(storagePath);
      onProgress?.call(1.0);
      return bytes;
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] downloadFile error: $e');
      return null;
    }
  }

  @override
  Future<void> deleteFile({required String storagePath}) async {
    if (!_service.isInitialized || _client == null) return;

    try {
      await _client!.storage.from('documents').remove([storagePath]);
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] deleteFile error: $e');
    }
  }

  // ===================================================================
  // ĐỒNG BỘ YÊU CẦU MƯỢN TRẢ TÀI LIỆU (BORROW REQUESTS SYNC)
  // ===================================================================

  Future<List<BorrowRequestModel>> pullBorrowRequests({
    required String userId,
    DateTime? since,
  }) async {
    if (!_service.isInitialized || _client == null) {
      return [];
    }
    try {
      var query = _client!
          .from('borrow_requests')
          .select('*, documents(title), profiles!borrower_id(display_name)')
          .or('borrower_id.eq.$userId,owner_id.eq.$userId');

      if (since != null) {
        query = query.gte('updated_at', since.toUtc().toIso8601String());
      }

      final rows = await query;
      return (rows as List)
          .map((row) => BorrowRequestModel.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] pullBorrowRequests error: $e');
      return [];
    }
  }

  Future<BorrowRequestModel?> pushBorrowRequest(BorrowRequestModel req) async {
    if (!_service.isInitialized || _client == null) return null;
    try {
      final payload = req.toSupabaseMap();
      final res = await _client!
          .from('borrow_requests')
          .upsert(payload)
          .select('*, documents(title), profiles!borrower_id(display_name)')
          .single();
      return BorrowRequestModel.fromSupabase(res);
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] pushBorrowRequest error: $e');
      return null;
    }
  }

  Future<bool> updateRemoteBorrowStatus({
    required String requestId,
    required String status,
  }) async {
    if (!_service.isInitialized || _client == null) return false;
    try {
      await _client!.from('borrow_requests').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (status == 'returned')
          'return_date': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] updateRemoteBorrowStatus error: $e');
      return false;
    }
  }

  // ===================================================================
  // ĐỒNG BỘ SỞ THÍCH NGƯỜI DÙNG (USER PROFILE & FAVORITE TAGS)
  // ===================================================================

  Future<bool> updateUserFavoriteTags({
    required String userId,
    required List<String> tags,
  }) async {
    if (!_service.isInitialized || _client == null) return false;
    try {
      await _client!.from('profiles').update({
        'favorite_tags': tags,
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] updateUserFavoriteTags error: $e');
      return false;
    }
  }

  Future<List<String>> fetchUserFavoriteTags(String userId) async {
    if (!_service.isInitialized || _client == null) return [];
    try {
      final res = await _client!
          .from('profiles')
          .select('favorite_tags')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && res['favorite_tags'] is List) {
        return (res['favorite_tags'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncService] fetchUserFavoriteTags error: $e');
      return [];
    }
  }
}
