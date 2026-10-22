// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/struct/models/borrow_request_model.dart
// Phụ trách: Checklist 01 (Core Architect) & Checklist 04 (Lending)
// Mô tả: Hợp đồng dữ liệu chung (Data Contract) cho nghiệp vụ Mượn/Trả
// tài liệu học tập giữa các sinh viên/người dùng.
// =====================================================================

import 'package:flutter/material.dart';

/// Trạng thái của một yêu cầu mượn tài liệu
enum BorrowStatus {
  pending,  // Đang chờ chủ sở hữu phê duyệt
  approved, // Đã duyệt, tài liệu đang được mượn
  rejected, // Bị từ chối
  returned, // Đã hoàn trả xong
}

extension BorrowStatusExtension on BorrowStatus {
  String get nameString {
    switch (this) {
      case BorrowStatus.pending:
        return 'pending';
      case BorrowStatus.approved:
        return 'approved';
      case BorrowStatus.rejected:
        return 'rejected';
      case BorrowStatus.returned:
        return 'returned';
    }
  }

  String get displayName {
    switch (this) {
      case BorrowStatus.pending:
        return 'Chờ duyệt';
      case BorrowStatus.approved:
        return 'Đang mượn';
      case BorrowStatus.rejected:
        return 'Đã từ chối';
      case BorrowStatus.returned:
        return 'Đã hoàn trả';
    }
  }

  Color get color {
    switch (this) {
      case BorrowStatus.pending:
        return const Color(0xFFFB8C00); // Cam
      case BorrowStatus.approved:
        return const Color(0xFF1E88E5); // Xanh dương
      case BorrowStatus.rejected:
        return const Color(0xFFE53935); // Đỏ
      case BorrowStatus.returned:
        return const Color(0xFF43A047); // Xanh lá
    }
  }

  IconData get icon {
    switch (this) {
      case BorrowStatus.pending:
        return Icons.hourglass_top_rounded;
      case BorrowStatus.approved:
        return Icons.menu_book_rounded;
      case BorrowStatus.rejected:
        return Icons.cancel_outlined;
      case BorrowStatus.returned:
        return Icons.check_circle_outline_rounded;
    }
  }

  static BorrowStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'approved':
        return BorrowStatus.approved;
      case 'rejected':
        return BorrowStatus.rejected;
      case 'returned':
        return BorrowStatus.returned;
      case 'pending':
      default:
        return BorrowStatus.pending;
    }
  }
}

/// Mô hình Mượn/Trả tài liệu học tập (Data Contract TH2)
class BorrowRequestModel {
  final String id;
  final String documentId;
  final String borrowerId;
  final String borrowerEmail;
  final String ownerId;
  final String status; // 'pending' | 'approved' | 'rejected' | 'returned'
  final DateTime requestDate;
  final DateTime? dueDate;
  final DateTime? returnDate;
  final String note;
  final DateTime createdDate;
  final DateTime updatedDate;

  // Metadata tài liệu đính kèm (hỗ trợ hiển thị UI tiện lợi không cần join thêm)
  final String? documentTitle;
  final String? borrowerName;
  final String? ownerEmail;

  BorrowRequestModel({
    required this.id,
    required this.documentId,
    required this.borrowerId,
    required this.borrowerEmail,
    required this.ownerId,
    this.status = 'pending',
    required this.requestDate,
    this.dueDate,
    this.returnDate,
    this.note = '',
    DateTime? createdDate,
    DateTime? updatedDate,
    this.documentTitle,
    this.borrowerName,
    this.ownerEmail,
  })  : createdDate = createdDate ?? requestDate,
        updatedDate = updatedDate ?? requestDate;

  BorrowStatus get borrowStatus => BorrowStatusExtension.fromString(status);

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isReturned => status == 'returned';

  /// Kiểm tra có đang mượn và quá hạn hay không
  bool get isOverdue {
    if (!isApproved || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Chuyển sang Map để lưu trữ trong SQLite cục bộ
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'borrower_id': borrowerId,
      'borrower_email': borrowerEmail,
      'owner_id': ownerId,
      'status': status,
      'request_date': requestDate.millisecondsSinceEpoch,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'return_date': returnDate?.millisecondsSinceEpoch,
      'note': note,
      'created_at': createdDate.millisecondsSinceEpoch,
      'updated_at': updatedDate.millisecondsSinceEpoch,
      'document_title': documentTitle,
      'borrower_name': borrowerName,
      'owner_email': ownerEmail,
    };
  }

  /// Chuyển sang Map để gửi lên Supabase Cloud (PostgreSQL columns)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'document_id': documentId,
      'borrower_id': borrowerId,
      'borrower_email': borrowerEmail,
      'owner_id': ownerId,
      'status': status,
      'request_date': requestDate.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'return_date': returnDate?.toUtc().toIso8601String(),
      'note': note,
      'created_at': createdDate.toUtc().toIso8601String(),
      'updated_at': updatedDate.toUtc().toIso8601String(),
    };
  }

  /// Tạo instance từ dòng dữ liệu SQLite
  factory BorrowRequestModel.fromMap(Map<String, dynamic> map) {
    DateTime parseEpoch(dynamic val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    DateTime? parseNullableEpoch(dynamic val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final reqDate = parseEpoch(map['request_date'], DateTime.now());

    return BorrowRequestModel(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      borrowerId: map['borrower_id']?.toString() ?? '',
      borrowerEmail: map['borrower_email']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      requestDate: reqDate,
      dueDate: parseNullableEpoch(map['due_date']),
      returnDate: parseNullableEpoch(map['return_date']),
      note: map['note']?.toString() ?? '',
      createdDate: parseEpoch(map['created_at'], reqDate),
      updatedDate: parseEpoch(map['updated_at'], reqDate),
      documentTitle: map['document_title']?.toString(),
      borrowerName: map['borrower_name']?.toString(),
      ownerEmail: map['owner_email']?.toString(),
    );
  }

  /// Tạo instance từ JSON trả về của Supabase Cloud
  factory BorrowRequestModel.fromSupabase(Map<String, dynamic> row) {
    DateTime parseIso(dynamic val, DateTime fallback) {
      if (val is String) {
        final dt = DateTime.tryParse(val);
        if (dt != null) return dt.toLocal();
      }
      return fallback;
    }

    DateTime? parseNullableIso(dynamic val) {
      if (val is String) {
        final dt = DateTime.tryParse(val);
        if (dt != null) return dt.toLocal();
      }
      return null;
    }

    final reqDate = parseIso(row['request_date'], DateTime.now());

    return BorrowRequestModel(
      id: row['id']?.toString() ?? '',
      documentId: row['document_id']?.toString() ?? '',
      borrowerId: row['borrower_id']?.toString() ?? '',
      borrowerEmail: row['borrower_email']?.toString() ?? '',
      ownerId: row['owner_id']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
      requestDate: reqDate,
      dueDate: parseNullableIso(row['due_date']),
      returnDate: parseNullableIso(row['return_date']),
      note: row['note']?.toString() ?? '',
      createdDate: parseIso(row['created_at'], reqDate),
      updatedDate: parseIso(row['updated_at'], reqDate),
      documentTitle: row['documents']?['title']?.toString() ??
          row['document_title']?.toString(),
      borrowerName: row['profiles']?['display_name']?.toString() ??
          row['borrower_name']?.toString(),
    );
  }

  BorrowRequestModel copyWith({
    String? id,
    String? documentId,
    String? borrowerId,
    String? borrowerEmail,
    String? ownerId,
    String? status,
    DateTime? requestDate,
    DateTime? dueDate,
    DateTime? returnDate,
    String? note,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? documentTitle,
    String? borrowerName,
    String? ownerEmail,
  }) {
    return BorrowRequestModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowerEmail: borrowerEmail ?? this.borrowerEmail,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      note: note ?? this.note,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? DateTime.now(),
      documentTitle: documentTitle ?? this.documentTitle,
      borrowerName: borrowerName ?? this.borrowerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
