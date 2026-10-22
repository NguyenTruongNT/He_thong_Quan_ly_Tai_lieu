// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/struct/borrow_service.dart
// Phụ trách: Checklist 04 (Lending Workflow) & Checklist 01 (Realtime Notification)
// Thành viên: Vũ Hải Đăng
// Mô tả: Lớp dịch vụ quản lý vòng đời Mượn / Trả tài liệu giữa các sinh viên:
//   - Gửi yêu cầu mượn tài liệu (Pending)
//   - Chủ sở hữu phê duyệt (Approved) hoặc Từ chối (Rejected)
//   - Hoàn trả tài liệu (Returned) & Nhận diện quá hạn (Overdue)
//   - Hỗ trợ lưu trữ Offline Cache qua SQLite và Đồng bộ Supabase Cloud
//   - Lắng nghe sự kiện thông báo thời gian thực (Supabase Realtime Channel)
// =====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../database/databaseGlobal.dart';
import 'models/borrow_request_model.dart';
import 'models/document_models.dart';
import 'supabase_service.dart';

class BorrowService {
  BorrowService._();

  static final BorrowService instance = BorrowService._();

  RealtimeChannel? _realtimeChannel;
  final _uuid = const Uuid();

  /// Controller phát thông báo Realtime cho giao diện UI
  final _notificationStreamController =
      StreamController<BorrowNotificationEvent>.broadcast();

  Stream<BorrowNotificationEvent> get notificationStream =>
      _notificationStreamController.stream;

  // =====================================================================
  // 1. NGHIỆP VỤ TẠO YÊU CẦU MƯỢN (CREATE BORROW REQUEST)
  // =====================================================================

  /// Sinh viên gửi yêu cầu mượn tài liệu học tập
  Future<BorrowRequestModel> createBorrowRequest({
    required DocumentModel document,
    required String borrowerId,
    required String borrowerEmail,
    String? borrowerName,
    DateTime? dueDate,
    String note = '',
    String? ownerId,
  }) async {
    final now = DateTime.now();
    final newId = 'req_${now.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';

    final resolvedOwnerId = ownerId ??
        await database.getDocumentOwnerId(document.id) ??
        'local';

    // 1. Tạo instance BorrowRequestModel
    final request = BorrowRequestModel(
      id: newId,
      documentId: document.id,
      borrowerId: borrowerId,
      borrowerEmail: borrowerEmail,
      ownerId: resolvedOwnerId,
      status: 'pending',
      requestDate: now,
      dueDate: dueDate ?? now.add(const Duration(days: 7)),
      note: note.trim(),
      createdDate: now,
      updatedDate: now,
      documentTitle: document.title,
      borrowerName: borrowerName,
    );

    // 2. Lưu vào SQLite Cache cục bộ (hoạt động offline ngay cả khi mất mạng)
    await database.insertBorrowRequest(request);

    // 3. Nếu đã kết nối Supabase Cloud & đã đăng nhập -> đẩy lên Supabase
    if (SupabaseService.instance.isInitialized &&
        SupabaseService.instance.currentUser != null) {
      try {
        await SupabaseService.instance.ensureDocumentExists(document);
        await SupabaseService.instance.sendBorrowRequest(
          documentId: document.id,
          dueDate: request.dueDate,
          note: request.note,
        );
        debugPrint('[BorrowService] Đã gửi yêu cầu mượn lên Supabase Cloud.');
      } catch (e) {
        debugPrint('[BorrowService] Gửi Supabase thất bại, giữ lưu local cache: $e');
      }
    }

    return request;
  }

  // =====================================================================
  // 2. PHÊ DUYỆT / TỪ CHỐI YÊU CẦU MƯỢN (APPROVE / REJECT)
  // =====================================================================

  /// Chủ sở hữu tài liệu chấp nhận yêu cầu mượn (Status -> Approved)
  Future<BorrowRequestModel> approveRequest(BorrowRequestModel request) async {
    final updated = request.copyWith(
      status: 'approved',
      updatedDate: DateTime.now(),
    );

    // 1. Cập nhật SQLite nội bộ
    await database.updateBorrowRequest(updated);

    // 2. Đồng bộ lên Supabase Cloud nếu có kết nối
    if (SupabaseService.instance.isInitialized &&
        SupabaseService.instance.currentUser != null) {
      try {
        await SupabaseService.instance.respondBorrowRequest(
          requestId: request.id,
          action: 'approved',
        );
      } catch (e) {
        debugPrint('[BorrowService] respondBorrowRequest cloud error: $e');
      }
    }

    return updated;
  }

  /// Chủ sở hữu tài liệu từ chối yêu cầu mượn (Status -> Rejected)
  Future<BorrowRequestModel> rejectRequest(
    BorrowRequestModel request, [
    String? reason,
  ]) async {
    final noteWithReason = (reason != null && reason.trim().isNotEmpty)
        ? '${request.note.isEmpty ? '' : '${request.note} | '}Lý do từ chối: ${reason.trim()}'
        : request.note;

    final updated = request.copyWith(
      status: 'rejected',
      note: noteWithReason,
      updatedDate: DateTime.now(),
    );

    // 1. Cập nhật SQLite nội bộ
    await database.updateBorrowRequest(updated);

    // 2. Đồng bộ lên Supabase Cloud nếu có kết nối
    if (SupabaseService.instance.isInitialized &&
        SupabaseService.instance.currentUser != null) {
      try {
        await SupabaseService.instance.respondBorrowRequest(
          requestId: request.id,
          action: 'rejected',
        );
      } catch (e) {
        debugPrint('[BorrowService] rejectRequest cloud error: $e');
      }
    }

    return updated;
  }

  // =====================================================================
  // 3. HOÀN TRẢ TÀI LIỆU (MARK AS RETURNED)
  // =====================================================================

  /// Đánh dấu tài liệu đã được hoàn trả (Status -> Returned)
  Future<BorrowRequestModel> markAsReturned(BorrowRequestModel request) async {
    final now = DateTime.now();
    final updated = request.copyWith(
      status: 'returned',
      returnDate: now,
      updatedDate: now,
    );

    // 1. Cập nhật SQLite nội bộ
    await database.updateBorrowRequest(updated);

    // 2. Đồng bộ lên Supabase Cloud nếu có kết nối
    if (SupabaseService.instance.isInitialized &&
        SupabaseService.instance.currentUser != null) {
      try {
        await SupabaseService.instance.markDocumentReturned(
          requestId: request.id,
        );
      } catch (e) {
        debugPrint('[BorrowService] markDocumentReturned cloud error: $e');
      }
    }

    return updated;
  }

  /// Xóa hoặc hủy yêu cầu mượn
  Future<void> deleteRequest(String requestId) async {
    await database.deleteBorrowRequest(requestId);
  }

  // =====================================================================
  // 4. TRUY VẤN DỮ LIỆU & REACTIVE STREAMS
  // =====================================================================

  /// Lấy danh sách các tài liệu mà người dùng đang mượn (vai trò Borrower)
  Future<List<BorrowRequestModel>> getRequestsForBorrower(String borrowerId) async {
    return database.getBorrowRequestsForBorrower(borrowerId);
  }

  /// Lấy danh sách các yêu cầu mượn gửi tới tài liệu của tôi (vai trò Owner)
  Future<List<BorrowRequestModel>> getRequestsForOwner(String ownerId) async {
    return database.getBorrowRequestsForOwner(ownerId);
  }

  /// Lấy toàn bộ danh sách mượn trả
  Future<List<BorrowRequestModel>> getAllRequests() async {
    return database.getAllBorrowRequests();
  }

  /// Luồng Reactive Stream theo dõi toàn bộ thay đổi mượn trả (phát dữ liệu hiện tại trước)
  Stream<List<BorrowRequestModel>> watchAllBorrowRequests() async* {
    yield await getAllRequests();
    yield* database.watchAllBorrowRequests;
  }

  /// Stream đếm số lượng yêu cầu mượn đang chờ duyệt của chủ sở hữu
  Stream<int> watchPendingCountForOwner(String ownerId) {
    return watchAllBorrowRequests().map((list) {
      return list.where((r) => r.ownerId == ownerId && r.isPending).length;
    });
  }

  // =====================================================================
  // 5. ĐỒNG BỘ VỚI SUPABASE CLOUD (CLOUD SYNC)
  // =====================================================================

  /// Kéo toàn bộ danh sách mượn trả từ Supabase Cloud về lưu SQLite Cache
  Future<void> syncWithCloud() async {
    if (!SupabaseService.instance.isInitialized ||
        SupabaseService.instance.currentUser == null) {
      return;
    }

    try {
      final cloudList =
          await SupabaseService.instance.getBorrowRequestsForCurrentUser();
      for (final req in cloudList) {
        await database.insertBorrowRequest(req);
      }
      debugPrint('[BorrowService] Đã đồng bộ ${cloudList.length} yêu cầu mượn từ Cloud.');
    } catch (e) {
      debugPrint('[BorrowService] Lỗi đồng bộ mượn trả từ Supabase: $e');
    }
  }

  // =====================================================================
  // 6. THÔNG BÁO REALTIME (SUPABASE REALTIME CHANNEL)
  // =====================================================================

  /// Đăng ký lắng nghe sự kiện Realtime khi có yêu cầu mượn hoặc duyệt mượn
  void startRealtimeListener({
    required String userId,
    void Function(BorrowNotificationEvent event)? onNotification,
  }) {
    if (!SupabaseService.instance.isInitialized ||
        SupabaseService.instance.client == null) {
      return;
    }

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.instance.subscribeBorrowRequests(
      userId: userId,
      onEvent: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord.isEmpty) return;

        try {
          final request = BorrowRequestModel.fromSupabase(newRecord);
          // Cập nhật ngay vào SQLite Cache
          database.insertBorrowRequest(request);

          BorrowNotificationEvent? event;
          if (payload.eventType == PostgresChangeEvent.insert) {
            if (request.ownerId == userId) {
              event = BorrowNotificationEvent(
                type: BorrowNotificationType.newRequestReceived,
                request: request,
                message:
                    '${request.borrowerEmail} vừa gửi yêu cầu mượn "${request.documentTitle ?? 'tài liệu'}"',
              );
            }
          } else if (payload.eventType == PostgresChangeEvent.update) {
            if (request.borrowerId == userId) {
              if (request.isApproved) {
                event = BorrowNotificationEvent(
                  type: BorrowNotificationType.requestApproved,
                  request: request,
                  message:
                      'Yêu cầu mượn "${request.documentTitle ?? 'tài liệu'}" của bạn đã được CHẤP NHẬN!',
                );
              } else if (request.isRejected) {
                event = BorrowNotificationEvent(
                  type: BorrowNotificationType.requestRejected,
                  request: request,
                  message:
                      'Yêu cầu mượn "${request.documentTitle ?? 'tài liệu'}" của bạn đã bị từ chối.',
                );
              }
            } else if (request.ownerId == userId && request.isReturned) {
              event = BorrowNotificationEvent(
                type: BorrowNotificationType.documentReturned,
                request: request,
                message:
                    '${request.borrowerEmail} đã hoàn trả tài liệu "${request.documentTitle ?? ''}"',
              );
            }
          }

          if (event != null) {
            _notificationStreamController.add(event);
            onNotification?.call(event);
          }
        } catch (e) {
          debugPrint('[BorrowService] Lỗi xử lý Realtime event: $e');
        }
      },
    );
  }

  /// Hủy lắng nghe Realtime khi đăng xuất hoặc thoát ứng dụng
  void stopRealtimeListener() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }
}

/// Loại sự kiện thông báo mượn trả
enum BorrowNotificationType {
  newRequestReceived, // Có người gửi yêu cầu mượn tới tôi
  requestApproved,    // Yêu cầu của tôi được chấp thuận
  requestRejected,    // Yêu cầu của tôi bị từ chối
  documentReturned,   // Tài liệu đã được hoàn trả
}

/// Mô hình sự kiện thông báo mượn trả
class BorrowNotificationEvent {
  final BorrowNotificationType type;
  final BorrowRequestModel request;
  final String message;
  final DateTime timestamp;

  BorrowNotificationEvent({
    required this.type,
    required this.request,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
