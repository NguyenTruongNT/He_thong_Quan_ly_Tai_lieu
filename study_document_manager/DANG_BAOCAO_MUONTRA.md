
### Phân công thành viên: Vũ Hải Đăng
- **Nhiệm vụ chính**: Xây dựng luồng mượn & chia sẻ tài liệu (Checklist 04 & Checklist 01), Cải tiến cơ chế đồng bộ Cloud & Offline Mode, Bổ sung xác thực OAuth.
- **Các thành phần (Classes / Functions) đã hiện thực**:

1. **`BorrowService` (`lib/struct/borrow_service.dart`)**:
   - Quản lý toàn bộ vòng đời mượn tài liệu giữa các người dùng:
     - `createBorrowRequest(...)`: Tạo yêu cầu mượn tài liệu mới kèm lời nhắn và thời hạn mượn.
     - `getMySentRequests(...)` & `getMyReceivedRequests(...)`: Truy vấn danh sách yêu cầu đã gửi và yêu cầu nhận được.
     - `getRequestsForDocument(...)`: Lấy lịch sử yêu cầu của một tài liệu cụ thể.
     - `respondToRequest(requestId, status)`: Chủ tài liệu phê duyệt (`approved`) hoặc từ chối (`rejected`) yêu cầu.
     - `returnDocument(requestId)`: Người mượn hoàn trả tài liệu (`returned`).

2. **Giao diện người dùng cho tính năng Mượn tài liệu (`lib/widgets/borrow/`, `lib/pages/borrow/`)**:
   - `BorrowRequestDialog`: Hộp thoại tương tác cho phép nhập lời nhắn và chọn ngày hết hạn mượn.
   - `BorrowManagementPage`: Màn hình quản lý yêu cầu mượn gồm 2 tab trực quan: "Yêu cầu đã gửi" và "Yêu cầu nhận được", hỗ trợ lọc trạng thái, xem chi tiết và thực hiện thao tác duyệt/từ chối/trả tài liệu.
   - Tích hợp nút hành động ngữ cảnh vào `DocumentDetailPage` (phân quyền: chủ sở hữu xem danh sách yêu cầu, người ngoài gửi yêu cầu mượn) và menu điều hướng trang chủ.

3. **Tối ưu hóa cơ chế Đồng bộ Cloud & Ngoại tuyến (`lib/struct/sync/`)**:
   - `SupabaseRemoteSyncService.push()`: Tự động upsert dữ liệu người dùng vào bảng `profiles` trước khi đẩy tài liệu, giải quyết triệt để lỗi ràng buộc khóa ngoại (`documents_owner_id_fkey`); chuẩn hóa giá trị mặc định cho `checksum_algo` (`sha256`).
   - `SyncEngine.ping()` & `SyncStatusBanner`: Hoàn thiện cơ chế nhận diện chế độ ngoại tuyến (Local/Offline Mode) khi chưa đăng nhập, hiển thị thông báo trạng thái thân thiện, loại bỏ lỗi đồng bộ giả.

4. **Kiểm thử tự động (`test/borrow_service_and_ui_test.dart`)**:
   - Viết bộ unit test & widget test bao phủ toàn bộ luồng mượn (tạo, duyệt, từ chối, trả) và kiểm thử giao diện `BorrowRequestDialog`.
   - Kết quả: Đạt 100% test pass (47/47 tests).