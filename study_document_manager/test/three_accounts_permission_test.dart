// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: test/three_accounts_permission_test.dart
// Mô tả: Kiểm thử Checklist 6 - Xác minh phân quyền trên ít nhất 3 tài khoản:
//   - Tài khoản 1 (Owner): Toàn quyền (Xem, Sửa, Xóa, Cấp/Thu hồi quyền)
//   - Tài khoản 2 (Viewer): Chỉ xem, Không được sửa, Không được xóa
//   - Tài khoản 3 (Editor): Xem và Sửa được, Không được xóa, Không được phân quyền
//   - Tài khoản 4 (Stranger): Người lạ không được chia sẻ, Không thấy tài liệu
// =====================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/struct/models/document_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase();
    await db.init(isInMemory: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Checklist 6: Kiểm thử luồng phân quyền với 3+ tài khoản người dùng', () {
    test('Xác minh đầy đủ quyền hạn của Owner, Viewer, Editor và Stranger', () async {
      final now = DateTime.now();

      // ---------------------------------------------------------------
      // BƯỚC 1: TÀI KHOẢN 1 (OWNER) TẠO MÔN HỌC, TÀI LIỆU VÀ CHIA SẺ
      // ---------------------------------------------------------------
      await db.setActiveOwner('owner-account');

      final testSubject = SubjectModel(
        id: 'sub_owner_swe',
        name: 'Kiến trúc & Thiết kế Phần mềm',
        code: 'SWE302',
        colorValue: 0xFF1E88E5,
        iconName: 'architecture',
        createdDate: now,
      );
      await db.insertSubject(testSubject);

      final testDoc = DocumentModel(
        id: 'doc_permission_suite_01',
        title: 'Báo cáo Kiểm thử Phân quyền 3 Tài khoản',
        subjectId: testSubject.id,
        type: DocumentType.lecture,
        notes: 'Ghi chú tài liệu dành cho kiểm thử bảo mật RLS.',
        tags: const ['Security', 'RLS', 'Permissions'],
        createdDate: now,
        updatedDate: now,
      );

      // Owner tạo tài liệu
      final insertResult = await db.insertDocument(testDoc);
      expect(insertResult, greaterThan(0));

      // Owner có toàn quyền
      expect(await db.canManageSharing(testDoc.id), isTrue);
      expect(await db.canEditDocument(testDoc.id), isTrue);

      // Owner chia sẻ cho Viewer (demo-user-1) và Editor (demo-user-2)
      await db.shareDocument(
        documentId: testDoc.id,
        targetUserId: 'demo-user-1',
        role: DocumentPermissionRole.viewer,
      );

      await db.shareDocument(
        documentId: testDoc.id,
        targetUserId: 'demo-user-2',
        role: DocumentPermissionRole.editor,
      );

      final permissions = await db.getDocumentPermissions(testDoc.id);
      expect(permissions.length, equals(2));
      expect(
        permissions.any((p) => p.sharedWithUserId == 'demo-user-1' && p.role == DocumentPermissionRole.viewer),
        isTrue,
      );
      expect(
        permissions.any((p) => p.sharedWithUserId == 'demo-user-2' && p.role == DocumentPermissionRole.editor),
        isTrue,
      );

      // ---------------------------------------------------------------
      // BƯỚC 2: TÀI KHOẢN 2 (VIEWER - DEMO-USER-1)
      // Kì vọng: Xem được, KHÔNG được sửa, KHÔNG được xóa, KHÔNG được chia sẻ
      // ---------------------------------------------------------------
      await db.setActiveOwner('demo-user-1');

      // 2.1. Xem tài liệu
      final viewerDoc = await db.getDocumentById(testDoc.id);
      expect(viewerDoc, isNotNull);
      expect(viewerDoc!.title, equals(testDoc.title));

      // 2.2. Kiểm tra cờ quyền
      expect(await db.canEditDocument(testDoc.id), isFalse);
      expect(await db.canManageSharing(testDoc.id), isFalse);

      final currentPerm = await db.getPermissionForCurrentUser(testDoc.id);
      expect(currentPerm?.role, equals(DocumentPermissionRole.viewer));

      // 2.3. Thử sửa tài liệu -> Phải bị từ chối (trả về 0)
      final unauthorizedUpdate = await db.updateDocument(
        testDoc.copyWith(title: 'Viewer cố tình sửa tiêu đề'),
      );
      expect(unauthorizedUpdate, equals(0));

      // 2.4. Thử xóa tài liệu -> Phải bị từ chối (trả về 0)
      final unauthorizedDelete = await db.deleteDocument(testDoc.id);
      expect(unauthorizedDelete, equals(0));

      // 2.5. Thử chia sẻ cho người khác -> Phải ném ngoại lệ StateError
      expect(
        () => db.shareDocument(
          documentId: testDoc.id,
          targetUserId: 'stranger-user',
          role: DocumentPermissionRole.viewer,
        ),
        throwsStateError,
      );

      // ---------------------------------------------------------------
      // BƯỚC 3: TÀI KHOẢN 3 (EDITOR - DEMO-USER-2)
      // Kì vọng: Xem được, SỬA ĐƯỢC, KHÔNG được xóa, KHÔNG được chia sẻ
      // ---------------------------------------------------------------
      await db.setActiveOwner('demo-user-2');

      // 3.1. Xem tài liệu
      final editorDoc = await db.getDocumentById(testDoc.id);
      expect(editorDoc, isNotNull);

      // 3.2. Kiểm tra cờ quyền
      expect(await db.canEditDocument(testDoc.id), isTrue);
      expect(await db.canManageSharing(testDoc.id), isFalse);

      // 3.3. Sửa tài liệu -> Thành công (trả về 1)
      final authorizedUpdate = await db.updateDocument(
        testDoc.copyWith(title: 'Tiêu đề đã được Editor cập nhật hợp lệ'),
      );
      expect(authorizedUpdate, equals(1));

      final updatedDoc = await db.getDocumentById(testDoc.id);
      expect(updatedDoc!.title, equals('Tiêu đề đã được Editor cập nhật hợp lệ'));

      // 3.4. Thử xóa tài liệu -> Bị từ chối (Editor không có quyền xóa tài sản của Owner)
      final editorDelete = await db.deleteDocument(testDoc.id);
      expect(editorDelete, equals(0));

      // 3.5. Thử chia sẻ tiếp -> Bị từ chối
      expect(
        () => db.shareDocument(
          documentId: testDoc.id,
          targetUserId: 'stranger-user',
          role: DocumentPermissionRole.viewer,
        ),
        throwsStateError,
      );

      // ---------------------------------------------------------------
      // BƯỚC 4: TÀI KHOẢN 4 (STRANGER - DEMO-USER-3 / NGƯỜI LẠ)
      // Kì vọng: Hoàn toàn KHÔNG nhìn thấy tài liệu, không tìm kiếm được
      // ---------------------------------------------------------------
      await db.setActiveOwner('demo-user-3');

      // 4.1. Không lấy được tài liệu theo ID
      expect(await db.getDocumentById(testDoc.id), isNull);

      // 4.2. Tìm kiếm từ khóa không trả về tài liệu này
      final searchResults = await db.searchDocuments(query: 'Phân quyền 3 Tài khoản');
      expect(searchResults.any((d) => d.id == testDoc.id), isFalse);

      // 4.3. Không có quyền sửa hoặc xóa
      expect(await db.canEditDocument(testDoc.id), isFalse);
      expect(await db.canManageSharing(testDoc.id), isFalse);
      expect(await db.updateDocument(testDoc.copyWith(title: 'Stranger hack')), equals(0));
      expect(await db.deleteDocument(testDoc.id), equals(0));

      // ---------------------------------------------------------------
      // BƯỚC 5: THU HỒI QUYỀN (REVOCATION) VÀ XÁC MINH LẠI
      // ---------------------------------------------------------------
      // Owner quay lại thu hồi quyền của Editor (demo-user-2)
      await db.setActiveOwner('owner-account');
      await db.revokeDocumentShare(
        documentId: testDoc.id,
        targetUserId: 'demo-user-2',
      );

      // Editor (demo-user-2) kiểm tra lại -> Không còn xem được tài liệu nữa!
      await db.setActiveOwner('demo-user-2');
      expect(await db.getDocumentById(testDoc.id), isNull);

      // ---------------------------------------------------------------
      // BƯỚC 6: OWNER XÓA TÀI LIỆU
      // ---------------------------------------------------------------
      await db.setActiveOwner('owner-account');
      final ownerDelete = await db.deleteDocument(testDoc.id);
      expect(ownerDelete, equals(1));
      expect(await db.getDocumentById(testDoc.id), isNull);
    });
  });
}
