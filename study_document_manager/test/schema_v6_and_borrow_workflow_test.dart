// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: test/schema_v6_and_borrow_workflow_test.dart
// Phụ trách: Checklist 01 & Checklist 06 - Nguyễn Văn Trường (Nhóm trưởng)
// Mô tả: Bộ kiểm thử tự động toàn diện cho:
//   1. Hợp đồng dữ liệu DocumentModel mở rộng (Bản đồ, Tọa độ, Vị trí vật lý)
//   2. Mô hình vòng đời Mượn / Trả tài liệu (BorrowRequestModel)
//   3. Hoạt động DAO của AppDatabase (SQLite / In-Memory Cache) cho mượn trả
//   4. Reactive Streams phát tín hiệu thời gian thực khi mượn trả thay đổi
// =====================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/models/borrow_request_model.dart';
import 'package:study_document_manager/struct/models/document_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Checklist 01: Kiểm thử Hợp đồng Dữ liệu (Data Contract)', () {
    test('1. DocumentModel lưu trữ và trích xuất đúng tọa độ GPS và vị trí vật lý', () {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'doc_map_001',
        title: 'Giáo trình Kỹ nghệ Phần mềm nâng cao',
        subjectId: 'sub_swe',
        type: DocumentType.reference,
        tags: const ['#SWE', '#CleanCode', '#Architecture'],
        latitude: 21.007425,
        longitude: 105.824712,
        locationName: 'Tủ B3, Thư viện Tạ Quang Bửu - ĐH Thủy Lợi',
        isPhysical: true,
        createdDate: now,
        updatedDate: now,
      );

      expect(doc.latitude, closeTo(21.0074, 0.0001));
      expect(doc.longitude, closeTo(105.8247, 0.0001));
      expect(doc.locationName, 'Tủ B3, Thư viện Tạ Quang Bửu - ĐH Thủy Lợi');
      expect(doc.isPhysical, isTrue);
      expect(doc.tags, containsAll(['#SWE', '#CleanCode']));

      // Kiểm thử chuyển đổi toMap và fromMap (tương thích SQLite)
      final map = doc.toMap();
      expect(map['latitude'], 21.007425);
      expect(map['longitude'], 105.824712);
      expect(map['location_name'], 'Tủ B3, Thư viện Tạ Quang Bửu - ĐH Thủy Lợi');
      expect(map['is_physical'], 1);

      final reconstructed = DocumentModel.fromMap(map);
      expect(reconstructed.id, doc.id);
      expect(reconstructed.latitude, doc.latitude);
      expect(reconstructed.longitude, doc.longitude);
      expect(reconstructed.locationName, doc.locationName);
      expect(reconstructed.isPhysical, isTrue);
      expect(reconstructed.tags, equals(doc.tags));
    });

    test('2. BorrowRequestModel chuyển đổi trạng thái (Pending -> Approved -> Returned)', () {
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 7));

      var req = BorrowRequestModel(
        id: 'req_001',
        documentId: 'doc_1',
        borrowerId: 'user_borrower_123',
        borrowerEmail: 'borrower@tlu.edu.vn',
        ownerId: 'user_owner_456',
        status: 'pending',
        requestDate: now,
        dueDate: dueDate,
        note: 'Em xin mượn sách 1 tuần để ôn thi môn SWE.',
      );

      expect(req.isPending, isTrue);
      expect(req.isApproved, isFalse);
      expect(req.isOverdue, isFalse);
      expect(req.borrowStatus, BorrowStatus.pending);

      // Phê duyệt yêu cầu (Approved)
      req = req.copyWith(status: 'approved');
      expect(req.isPending, isFalse);
      expect(req.isApproved, isTrue);
      expect(req.borrowStatus, BorrowStatus.approved);

      // Hoàn trả tài liệu (Returned)
      final returnDate = DateTime.now();
      req = req.copyWith(status: 'returned', returnDate: returnDate);
      expect(req.isApproved, isFalse);
      expect(req.isReturned, isTrue);
      expect(req.returnDate, returnDate);
      expect(req.borrowStatus, BorrowStatus.returned);
    });

    test('3. BorrowRequestModel phát hiện quá hạn trả chính xác', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final overdueReq = BorrowRequestModel(
        id: 'req_overdue',
        documentId: 'doc_2',
        borrowerId: 'user_1',
        borrowerEmail: 'user1@tlu.edu.vn',
        ownerId: 'user_2',
        status: 'approved',
        requestDate: pastDate.subtract(const Duration(days: 5)),
        dueDate: pastDate, // Đã quá hạn 2 ngày trước
      );

      expect(overdueReq.isApproved, isTrue);
      expect(overdueReq.isOverdue, isTrue);
    });

    test('4. BorrowRequestModel tương thích định dạng Supabase Cloud DDL', () {
      final now = DateTime.now().toUtc();
      final req = BorrowRequestModel(
        id: 'b1234567-89ab-cdef-0123-456789abcdef',
        documentId: 'd1234567-89ab-cdef-0123-456789abcdef',
        borrowerId: 'u1234567-89ab-cdef-0123-456789abcdef',
        borrowerEmail: 'sv1@tlu.edu.vn',
        ownerId: 'u7654321-89ab-cdef-0123-456789abcdef',
        status: 'pending',
        requestDate: now,
        note: 'Mượn tài liệu',
      );

      final supabaseMap = req.toSupabaseMap();
      expect(supabaseMap['id'], req.id);
      expect(supabaseMap['borrower_email'], 'sv1@tlu.edu.vn');
      expect(supabaseMap['request_date'], isNotNull);

      // Tái tạo lại từ JSON Supabase
      final fromCloud = BorrowRequestModel.fromSupabase({
        ...supabaseMap,
        'documents': {'title': 'Tài liệu Thủy Lợi'},
        'profiles': {'display_name': 'Sinh viên A'},
      });

      expect(fromCloud.id, req.id);
      expect(fromCloud.documentTitle, 'Tài liệu Thủy Lợi');
      expect(fromCloud.borrowerName, 'Sinh viên A');
    });
  });

  group('Checklist 01: Kiểm thử Tầng CSDL Cục bộ AppDatabase (DAO Mượn/Trả)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase();
      await db.init(isInMemory: true);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Tạo và truy vấn yêu cầu mượn tài liệu theo vai trò (Borrower & Owner)', () async {
      final now = DateTime.now();
      final req1 = BorrowRequestModel(
        id: 'borrow_req_test_1',
        documentId: 'doc_1',
        borrowerId: 'student_A',
        borrowerEmail: 'student_a@tlu.edu.vn',
        ownerId: 'teacher_B',
        status: 'pending',
        requestDate: now,
        note: 'Em xin mượn sách',
      );

      final req2 = BorrowRequestModel(
        id: 'borrow_req_test_2',
        documentId: 'doc_2',
        borrowerId: 'student_C',
        borrowerEmail: 'student_c@tlu.edu.vn',
        ownerId: 'teacher_B',
        status: 'pending',
        requestDate: now,
        note: 'Em xin mượn đề cương',
      );

      // Thêm 2 yêu cầu vào CSDL
      await db.insertBorrowRequest(req1);
      await db.insertBorrowRequest(req2);

      // Truy vấn theo Borrower
      final borrowerAList = await db.getBorrowRequestsForBorrower('student_A');
      expect(borrowerAList.length, 1);
      expect(borrowerAList.first.id, 'borrow_req_test_1');

      // Truy vấn theo Owner (Người sở hữu nhận được cả 2 yêu cầu)
      final ownerBList = await db.getBorrowRequestsForOwner('teacher_B');
      expect(ownerBList.length, 2);

      // Lấy chi tiết theo ID
      final fetched = await db.getBorrowRequestById('borrow_req_test_1');
      expect(fetched, isNotNull);
      expect(fetched!.borrowerEmail, 'student_a@tlu.edu.vn');
    });

    test('2. Cập nhật trạng thái duyệt mượn và xóa yêu cầu', () async {
      final now = DateTime.now();
      final req = BorrowRequestModel(
        id: 'req_to_approve',
        documentId: 'doc_1',
        borrowerId: 'user_X',
        borrowerEmail: 'x@tlu.edu.vn',
        ownerId: 'user_Y',
        status: 'pending',
        requestDate: now,
      );

      await db.insertBorrowRequest(req);

      // Duyệt mượn
      final approved = req.copyWith(status: 'approved');
      await db.updateBorrowRequest(approved);

      final updated = await db.getBorrowRequestById('req_to_approve');
      expect(updated?.status, 'approved');
      expect(updated?.isApproved, isTrue);

      // Xóa yêu cầu
      await db.deleteBorrowRequest('req_to_approve');
      final deleted = await db.getBorrowRequestById('req_to_approve');
      expect(deleted, isNull);
    });

    test('3. Reactive Stream watchAllBorrowRequests phát tín hiệu khi CSDL thay đổi', () async {
      final streamListFuture = db.watchAllBorrowRequests.first;

      final req = BorrowRequestModel(
        id: 'stream_test_req',
        documentId: 'doc_3',
        borrowerId: 'stream_user',
        borrowerEmail: 'stream@tlu.edu.vn',
        ownerId: 'owner_user',
        status: 'pending',
        requestDate: DateTime.now(),
      );

      await db.insertBorrowRequest(req);

      final emittedList = await streamListFuture;
      expect(emittedList.any((r) => r.id == 'stream_test_req'), isTrue);
    });
  });
}
