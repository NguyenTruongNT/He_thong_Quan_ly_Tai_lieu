# Hướng dẫn Thiết lập Supabase & Kiểm thử Phân quyền (Supabase Setup & Testing Guide)

Ứng dụng hiện đã được **tích hợp đầy đủ SDK Supabase Flutter** (`supabase_flutter`), sẵn sàng kết nối 2 chiều giữa ứng dụng Flutter và nền tảng Supabase Cloud (hoàn toàn **Miễn phí 100%**, không yêu cầu thẻ tín dụng).

Ứng dụng hỗ trợ linh hoạt 2 chế độ:
1. **Chế độ Ngoại tuyến / Demo (Offline SQLite Mode - Mặc định):** Chạy ngay lập tức không cần mạng, không cần tạo tài khoản Cloud, chuyển đổi mượt mà giữa 4 tài khoản (`local`, `demo-user-1`, `demo-user-2`, `demo-user-3`) để kiểm thử và báo cáo đầy đủ Checklist.
2. **Chế độ Supabase Cloud Trực tiếp (Live Supabase Cloud Mode):** Đồng bộ dữ liệu PostgreSQL, bảo vệ dữ liệu với Row Level Security (RLS) và lưu trữ tệp tin trên Supabase Storage bucket `documents`.

---

## 1. Thiết lập Dự án Supabase Miễn phí (Zero Cost / No Credit Card)

1. Truy cập <https://supabase.com> và đăng ký/đăng nhập tài khoản miễn phí.
2. Nhấn **New Project**:
   - **Name:** `Study Document Manager` (hoặc tên tùy chọn).
   - **Database Password:** Đặt mật khẩu an toàn và lưu lại.
   - **Region:** Chọn khu vực gần bạn nhất (ví dụ: `Southeast Asia (Singapore)`).
   - **Pricing Plan:** Chọn **Free Plan** (0$/tháng).
   - Nhấn **Create new project** và đợi 1-2 phút để Supabase khởi tạo.
3. Chạy cấu trúc Database & Chính sách bảo mật RLS:
   - Trong thanh menu bên trái, chọn **SQL Editor**.
   - Mở tệp [`supabase/schema.sql`](./supabase/schema.sql) trong dự án này, copy toàn bộ nội dung và dán vào SQL Editor.
   - Nhấn **Run** (Ctrl + Enter).
   - SQL script sẽ tự động tạo:
     - Bảng `public.profiles` (Người dùng) kèm trigger tự đồng bộ.
     - Bảng `public.documents` (Tài liệu) kèm index.
     - Bảng `public.document_permissions` (Quyền chia sẻ viewer/editor).
     - Kích hoạt RLS và thiết lập toàn bộ chính sách bảo mật cho từng bảng.
     - Tạo private Storage bucket `documents` (giới hạn 20 MiB, hỗ trợ PDF/Word/Excel/PowerPoint/Text).
     - Tạo Stored Procedure `share_document_by_email` và `revoke_document_share_by_email`.
4. Lấy thông tin kết nối API:
   - Vào **Project Settings** (biểu tượng bánh răng) > **API**.
   - Copy **Project URL** (ví dụ: `https://xyzcompany.supabase.co`).
   - Copy **Project API keys** > `anon` `public` key. *(Lưu ý: Không bao giờ sử dụng key `service_role` trong ứng dụng phía client).*

---

## 2. Kết nối Supabase vào Ứng dụng Flutter

Có 2 cách cực kỳ thuận tiện để kết nối:

### Cách 1: Cấu hình trực tiếp trên giao diện ứng dụng (Khuyến nghị)
1. Chạy ứng dụng: `flutter run -d chrome` hoặc `flutter run -d windows` / `flutter run -d android`.
2. Mở mục **Tài khoản & Thiết lập Cloud** (hoặc icon tài khoản trên AppBar).
3. Chọn Tab **Supabase Cloud**.
4. Dán **Project URL** và **Anon Key** đã copy ở Bước 1.
5. Nhấn **Lưu & Kết nối Supabase**. Ứng dụng sẽ tự động lưu cấu hình vào máy và kết nối tức thì!
6. Bạn có thể nhập Email & Mật khẩu bên dưới để Đăng ký / Đăng nhập tài khoản người dùng Supabase Auth.

### Cách 2: Truyền biến môi trường khi biên dịch
Chạy ứng dụng với cờ lệnh `--dart-define`:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://YOUR_PROJECT.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
```

---

## 3. Kiểm thử Phân quyền 3 Tài khoản (Checklist 6)

### Cách A: Kiểm thử tự động bằng Flutter Test (Nhanh nhất & Đạt 100%)
Từ thư mục `study_document_manager`, chạy lệnh:
```bash
flutter test test/three_accounts_permission_test.dart
```
Bài kiểm thử thực hiện kiểm tra toàn diện:
- **Tài khoản 1 (Owner):** Tạo tài liệu, cấp quyền `viewer` cho User 2 và `editor` cho User 3. Thử sửa -> Thành công; Xóa -> Thành công; Thu hồi quyền -> Thành công.
- **Tài khoản 2 (Viewer):** Đọc được tài liệu; Thử sửa -> Bị từ chối (trả về 0); Thử xóa -> Bị từ chối (trả về 0); Thử phân quyền -> Bị từ chối.
- **Tài khoản 3 (Editor):** Đọc được tài liệu; Sửa tiêu đề/ghi chú -> Thành công (trả về 1); Thử xóa -> Bị từ chối; Thử phân quyền -> Bị từ chối.
- **Tài khoản 4 (Stranger):** Người lạ không được chia sẻ -> Hoàn toàn không nhìn thấy tài liệu, tìm kiếm không ra kết quả.

### Cách B: Kiểm thử trực tiếp trên Supabase SQL Editor
1. Mở **SQL Editor** trên Supabase Dashboard.
2. Dán nội dung tệp [`supabase/test_rls_policies.sql`](./supabase/test_rls_policies.sql) vào và nhấn **Run**.
3. Bạn sẽ quan sát thấy RLS của PostgreSQL thực thi chính xác:
   - Owner SELECT và UPDATE thành công.
   - Viewer SELECT thành công, UPDATE trả về 0 row affected (bị chặn), DELETE trả về 0 (bị chặn).
   - Editor SELECT và UPDATE thành công, DELETE bị chặn.
   - Stranger SELECT trả về 0 row (hoàn toàn ẩn).

### Cách C: Kiểm thử trực quan trên giao diện ứng dụng (Offline / Live)
1. Mở ứng dụng, vào tab **Demo 3 Tài khoản** trong trang Tài khoản.
2. Đang ở `Tài khoản 1 (Owner)`: Bấm tạo tài liệu, mở tài liệu, nhấn nút **Chia sẻ**.
3. Bấm chip gợi ý `demo-user-1` (Chỉ xem) và nhấn **Chia sẻ**.
4. Bấm chip gợi ý `demo-user-2` (Có thể sửa) và nhấn **Chia sẻ**.
5. Vào lại trang Tài khoản, chuyển sang `Tài khoản 2 (Viewer - demo-user-1)`:
   - Tài liệu hiển thị trong danh sách.
   - Mở tài liệu: Bấm thử sửa -> Ứng dụng báo không có quyền chỉnh sửa. Nút xóa bị ẩn.
6. Chuyển sang `Tài khoản 3 (Editor - demo-user-2)`:
   - Mở tài liệu: Bấm Sửa -> Chỉnh sửa và lưu thành công! Thử xóa -> Bị từ chối.
7. Chuyển sang `Tài khoản 4 (Stranger - demo-user-3)`:
   - Tài liệu hoàn toàn biến mất khỏi danh sách và kết quả tìm kiếm.

---

## 4. Bảng đối chiếu hoàn thành Checklist (Checklist Compliance Matrix)

| Checklist | Nội dung yêu cầu | Trạng thái | Minh chứng thực hiện |
|---|---|:---:|---|
| **Checklist 1** | Thiết lập Firebase & Đăng nhập Google | **Hoàn thành** | `lib/struct/google_auth_service.dart`, `lib/pages/login_page.dart`, `lib/pages/auth_gate.dart`. Gói Spark 100% miễn phí, có cờ bật/tắt linh hoạt. |
| **Checklist 2** | Cấu trúc lưu trữ Storage & Liên kết metadata Supabase | **Hoàn thành** | Firebase Storage (`storage.rules`) và Supabase Storage (`supabase/schema.sql` bucket `documents`). Cột `file_path`, `file_url`, `checksum` trong bảng `documents`. |
| **Checklist 3** | Thiết kế CSDL Supabase (Users, Documents, Permissions) | **Hoàn thành** | `supabase/schema.sql` gồm các bảng `profiles`, `documents`, `document_permissions` với đầy đủ khóa ngoại, ràng buộc và chỉ mục. |
| **Checklist 4** | Tìm kiếm, cập nhật và chia sẻ tài liệu | **Hoàn thành** | Tìm kiếm đa tiêu chí (`document_search_page.dart`), cập nhật (`add_edit_document_page.dart`), chia sẻ và thu hồi quyền (`document_detail_page.dart`). |
| **Checklist 5** | Thiết lập Row Level Security (RLS) trên Supabase | **Hoàn thành** | `supabase/schema.sql` (8 chính sách RLS cho 3 bảng + 4 chính sách RLS cho Storage) và kịch bản kiểm thử SQL `supabase/test_rls_policies.sql`. |
| **Checklist 6** | Kiểm thử 3 tài khoản xác minh quyền hạn | **Hoàn thành** | `test/three_accounts_permission_test.dart` (59 tests pass), SQL RLS test và bộ chuyển đổi tài khoản trực tiếp trong ứng dụng. |
