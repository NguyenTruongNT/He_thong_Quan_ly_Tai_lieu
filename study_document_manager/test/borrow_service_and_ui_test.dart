// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: test/borrow_service_and_ui_test.dart
// Phụ trách: Checklist 04 (Lending Workflow) - Vũ Hải Đăng
// Mô tả: Bộ kiểm thử tự động toàn diện cho:
//   1. Nghiệp vụ BorrowService (Tạo, Duyệt, Từ chối, Báo trả sách, Hủy)
//   2. Reactive Stream và Stream đếm số lượng chờ duyệt
//   3. Giao diện BorrowRequestDialog (Hiển thị chi tiết, chọn thời hạn, gửi yêu cầu)
//   4. Giao diện BorrowManagementPage (Tab Người mượn & Chủ tài liệu, bộ lọc)
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/database/databaseGlobal.dart';
import 'package:study_document_manager/pages/borrow/borrow_management_page.dart';
import 'package:study_document_manager/struct/borrow_service.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/widgets/borrow/borrow_request_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DocumentModel mockDocument;

  setUp(() async {
    db = AppDatabase();
    await db.init(isInMemory: true);
    database = db;

    mockDocument = DocumentModel(
      id: 'doc_math_01',
      title: 'Giáo trình Giải tích 1',
      subjectId: 'sub_swe',
      type: DocumentType.reference,
      isPhysical: true,
      locationName: 'Thư viện Tạ Quang Bửu - Kệ B4',
      latitude: 21.0049,
      longitude: 105.8459,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    await database.insertDocument(mockDocument);
  });

  tearDown(() async {
    await db.close();
  });

  group('Checklist 04: Kiểm thử Nghiệp vụ BorrowService (Vũ Hải Đăng)', () {
    test('1. Tạo yêu cầu mượn tài liệu với thông tin hợp lệ', () async {
      final dueDate = DateTime.now().add(const Duration(days: 7));
      final request = await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        borrowerName: 'Vũ Hải Đăng',
        dueDate: dueDate,
        note: 'Em xin mượn sách để ôn thi học kỳ.',
        ownerId: 'teacher_an',
      );

      expect(request.id, startsWith('req_'));
      expect(request.documentId, 'doc_math_01');
      expect(request.borrowerId, 'user_dang');
      expect(request.borrowerEmail, 'dang.vh@tlu.edu.vn');
      expect(request.borrowerName, 'Vũ Hải Đăng');
      expect(request.ownerId, 'teacher_an');
      expect(request.status, 'pending');
      expect(request.documentTitle, 'Giáo trình Giải tích 1');
      expect(request.isPending, isTrue);
      expect(request.isOverdue, isFalse);

      // Xác thực lưu trữ trong CSDL
      final savedInDb = await database.getBorrowRequestById(request.id);
      expect(savedInDb, isNotNull);
      expect(savedInDb!.documentTitle, 'Giáo trình Giải tích 1');
    });

    test('2. Quy trình Duyệt yêu cầu mượn (approveRequest)', () async {
      final request = await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        ownerId: 'teacher_an',
      );

      final approved = await BorrowService.instance.approveRequest(request);
      expect(approved.status, 'approved');
      expect(approved.isApproved, isTrue);

      final inDb = await database.getBorrowRequestById(request.id);
      expect(inDb?.status, 'approved');
    });

    test('3. Quy trình Từ chối yêu cầu mượn kèm lý do (rejectRequest)', () async {
      final request = await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        ownerId: 'teacher_an',
      );

      final rejected = await BorrowService.instance.rejectRequest(
        request,
        'Sách hiện đã có bạn khác đang mượn.',
      );

      expect(rejected.status, 'rejected');
      expect(rejected.isRejected, isTrue);
      expect(rejected.note, contains('Sách hiện đã có bạn khác đang mượn.'));

      final inDb = await database.getBorrowRequestById(request.id);
      expect(inDb?.status, 'rejected');
    });

    test('4. Quy trình Trả sách và xác nhận đã nhận lại (markAsReturned)', () async {
      final request = await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        ownerId: 'teacher_an',
      );

      final approved = await BorrowService.instance.approveRequest(request);
      final returned = await BorrowService.instance.markAsReturned(approved);

      expect(returned.status, 'returned');
      expect(returned.isReturned, isTrue);
      expect(returned.returnDate, isNotNull);

      final inDb = await database.getBorrowRequestById(request.id);
      expect(inDb?.status, 'returned');
      expect(inDb?.returnDate, isNotNull);
    });

    test('5. Hủy/Xóa yêu cầu mượn tài liệu (deleteRequest)', () async {
      final request = await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        ownerId: 'teacher_an',
      );

      await BorrowService.instance.deleteRequest(request.id);
      final inDb = await database.getBorrowRequestById(request.id);
      expect(inDb, isNull);
    });

    test('6. Phân luồng truy vấn theo Borrower và Owner', () async {
      await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        ownerId: 'teacher_an',
      );
      await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_binh',
        borrowerEmail: 'binh.nv@tlu.edu.vn',
        ownerId: 'teacher_an',
      );

      final dangRequests = await BorrowService.instance.getRequestsForBorrower('user_dang');
      expect(dangRequests.length, 1);
      expect(dangRequests.first.borrowerId, 'user_dang');

      final teacherRequests = await BorrowService.instance.getRequestsForOwner('teacher_an');
      expect(teacherRequests.length, 2);
    });

    test('7. Reactive Stream watchPendingCountForOwner', () async {
      final events = <int>[];
      final subscription = BorrowService.instance
          .watchPendingCountForOwner('teacher_an')
          .listen(events.add);

      // Đợi stream phát giá trị ban đầu (0)
      await Future.delayed(const Duration(milliseconds: 50));

      final req1 = await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_dang',
        borrowerEmail: 'dang.vh@tlu.edu.vn',
        ownerId: 'teacher_an',
      );
      await Future.delayed(const Duration(milliseconds: 50));

      await BorrowService.instance.createBorrowRequest(
        document: mockDocument,
        borrowerId: 'user_binh',
        borrowerEmail: 'binh.nv@tlu.edu.vn',
        ownerId: 'teacher_an',
      );
      await Future.delayed(const Duration(milliseconds: 50));

      await BorrowService.instance.approveRequest(req1);
      await Future.delayed(const Duration(milliseconds: 50));

      await subscription.cancel();

      expect(events, equals([0, 1, 2, 1]));
    });
  });

  group('Checklist 04: Kiểm thử Giao diện Người dùng Mượn/Trả (UI Widgets)', () {
    testWidgets('1. BorrowRequestDialog hiển thị đúng thông tin tài liệu và cho phép chọn hạn trả',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  BorrowRequestDialog.show(
                    context,
                    document: mockDocument,
                  );
                },
                child: const Text('Mượn sách'),
              ),
            ),
          ),
        ),
      );

      // Bấm nút để mở dialog
      await tester.tap(find.text('Mượn sách'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra tiêu đề và thông tin tài liệu
      expect(find.text('Yêu cầu mượn tài liệu'), findsOneWidget);
      expect(find.text('Giáo trình Giải tích 1'), findsOneWidget);
      expect(find.textContaining('Kệ B4'), findsOneWidget);

      // Kiểm tra các chip chọn nhanh thời hạn
      expect(find.text('3 ngày'), findsOneWidget);
      expect(find.textContaining('7 ngày'), findsOneWidget);
      expect(find.textContaining('14 ngày'), findsOneWidget);
      expect(find.textContaining('30 ngày'), findsOneWidget);

      // Chọn chip 14 ngày
      await tester.tap(find.textContaining('14 ngày'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra nút hành động Hủy và Gửi yêu cầu mượn
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Gửi yêu cầu mượn'), findsOneWidget);
    });

    testWidgets('2. BorrowManagementPage hiển thị tab Người mượn và Chủ tài liệu',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Chuẩn bị 1 yêu cầu mượn mẫu trong môi trường runAsync
      await tester.runAsync(() async {
        await BorrowService.instance.createBorrowRequest(
          document: mockDocument,
          borrowerId: 'local',
          borrowerEmail: 'local@cashew.app',
          ownerId: 'local',
          note: 'Kiểm thử UI quản lý mượn trả',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: BorrowManagementPage(),
        ),
      );

      // Cho phép StreamBuilder nạp dữ liệu từ SQLite
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Kiểm tra tiêu đề AppBar
      expect(find.text('Quản lý Mượn / Trả tài liệu'), findsOneWidget);

      // Kiểm tra 2 tab chính
      expect(find.text('Tôi đang mượn'), findsOneWidget);
      expect(find.text('Yêu cầu tới tôi'), findsOneWidget);

      // Kiểm tra thông tin thẻ yêu cầu đang hiển thị
      expect(find.text('Giáo trình Giải tích 1'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsWidgets);

      // Chuyển sang Tab 2: "Yêu cầu tới tôi"
      await tester.tap(find.text('Yêu cầu tới tôi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kiểm tra các nút duyệt "Cho mượn" và "Từ chối" trên vai trò Owner
      expect(find.text('Cho mượn'), findsWidgets);
      expect(find.text('Từ chối'), findsWidgets);
    });
  });
}
