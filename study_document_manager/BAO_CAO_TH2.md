# BÁO CÁO TỔNG KẾT NGHIỆM THU ĐỀ TÀI TH2
## HỆ THỐNG QUẢN LÝ TÀI LIỆU ĐA NỀN TẢNG (FLUTTER + FIREBASE + SUPABASE)

> **Học phần:** Phát triển Ứng dụng Đa nền tảng (CSE441)  
> **Lớp:** 65KTPM — Khoa Công nghệ Thông tin, Trường Đại học Thủy Lợi  
> **Nhóm thực hiện:** Nhóm 12  
> **Dự án:** `study_document_manager`  
> **Ngày hoàn thành nghiệm thu:** 22/10/2026  

---

## 👥 THÔNG TIN NHÓM VÀ BẢNG PHÂN CÔNG TRÁCH NHIỆM

| STT | Họ và Tên | Mã sinh viên | Vai trò | Checklist phụ trách | Tỷ lệ hoàn thành |
| :---: | :--- | :---: | :--- | :--- | :---: |
| 1 | **Nguyễn Văn Trường** *(Trưởng nhóm)* | 2351172651 | **Core Architect & QA** | **Checklist 01 & Checklist 06** | **100%** |
| 2 | **Vũ Tuấn Khanh** | 2351172464 | **Map & Tagging Engineer** | **Checklist 03** | **100%** |
| 3 | **Vũ Hải Đăng** | 2351172450 | **Lending & Notification Engineer** | **Checklist 04 & 01 (Msg/Realtime)** | **100%** |
| 4 | **Lý Đình Sơn** | 2351172633 | **Algorithm & Responsive UI Engineer** | **Checklist 05 & Checklist 02** | **100%** |

---

## 📊 TỔNG QUAN ĐỐI SOÁT 6 CHECKLIST CỦA ĐỀ TÀI TH2

| Mục Checklist | Nội dung yêu cầu của Giảng viên | Thành viên phụ trách | Trạng thái kỹ thuật | Đánh giá nghiệm thu |
| :---: | :--- | :--- | :---: | :---: |
| **01** | Thiết kế kiến trúc hệ thống và mô hình dữ liệu kết hợp giữa Firebase (Auth/Messaging) và Supabase (DB/Storage). | Nguyễn Văn Trường & Vũ Hải Đăng | ✅ Đã hoàn thiện | **Đạt 100%** — Hybrid Cloud Decoupled, Supabase Schema + RLS, SQLite Cache Schema v6. |
| **02** | Xây dựng giao diện người dùng đa nền tảng bằng Flutter, đảm bảo tính đáp ứng (responsive) cho Mobile và Web. | Lý Đình Sơn | ✅ Đã hoàn thiện | **Đạt 100%** — `ResponsiveLayout`, Master-Detail trên Web/Desktop ($\ge 720\text{px}$), thích ứng 1/2/3 cột. |
| **03** | Triển khai tính năng phân loại tài liệu bằng Tag và tích hợp bản đồ/vị trí để quản lý vị trí vật lý của tài liệu. | Vũ Tuấn Khanh | ✅ Đã hoàn thiện | **Đạt 100%** — `TagInputField` (InputChip), `LocationPickerBottomSheet`, `DocumentMapPage` (OpenStreetMap). |
| **04** | Xây dựng luồng nghiệp vụ cho phép người dùng yêu cầu mượn và chia sẻ quyền truy cập tài liệu cho người khác. | Vũ Hải Đăng | ✅ Đã hoàn thiện | **Đạt 100%** — `BorrowService` (State Machine), `BorrowManagementPage` (2 tab), `BorrowRequestDialog`, Realtime badge. |
| **05** | Phát triển thuật toán Recommendation đơn giản để gợi ý tài liệu dựa trên sở thích hoặc tag của người dùng. | Lý Đình Sơn | ✅ Đã hoàn thiện | **Đạt 100%** — Content-Based Recommendation, tính điểm tương đồng, hiển thị `RecommendedSection` với AI Match badge. |
| **06** | Kiểm thử toàn diện các tính năng và đóng gói sản phẩm. | Nguyễn Văn Trường | ✅ Đã hoàn thiện | **Đạt 100%** — **87/87 tests PASSED**, `flutter analyze` 0 lỗi, Build Web Release thành công. |

---

## 🛠️ CHI TIẾT KẾT QUẢ TRIỂN KHAI TỪNG CHECKLIST

### 1. Checklist 01: Kiến trúc Hybrid Cloud & Mô hình CSDL kết hợp (Firebase + Supabase)
- **Kiến trúc Decoupled:**
  - **Firebase Authentication:** Đăng nhập một chạm bằng Google Sign-In, quản lý phiên làm việc JWT an toàn không cần máy chủ phụ trợ.
  - **Supabase PostgreSQL:** Lưu trữ dữ liệu quan hệ (`documents`, `borrow_requests`, `profiles`, `document_permissions`) với chính sách an ninh cấp hàng (RLS Policies) phân quyền chặt chẽ giữa Borrower và Owner.
  - **Supabase Storage:** Lưu trữ tệp tin đính kèm (PDF, DOCX, Slide) hỗ trợ tệp tới 20MB.
  - **Supabase Realtime:** Thiết lập kênh WebSocket trên bảng `borrow_requests` phát tín hiệu cập nhật trạng thái mượn sách tức thì.
  - **Firebase Cloud Messaging / Notification Stream:** Đẩy thông báo sự kiện mượn trả tới ứng dụng người dùng.
- **CSDL Cục bộ SQLite Cache (Schema Version 6):**
  - Mở rộng bảng `documents` với các cột tọa độ `latitude`, `longitude`, `location_name`, `is_physical`.
  - Bổ sung bảng `borrow_requests` phục vụ truy vấn và lưu tạm ngoại tuyến (Offline-First).
  - Tích hợp `SyncEngine` hỗ trợ xếp hàng ngoại tuyến (`sync_outbox`), ghi nhận xóa mềm (`delete_logs`), và giải quyết xung đột LWW (Last-Write-Wins).

### 2. Checklist 02: Giao diện thích ứng Responsive Đa nền tảng (Mobile & Web)
- **Điểm ngắt thích ứng (Breakpoints):** Mobile `< 600px`, Tablet `600px - 1024px`, Desktop/Web `> 1024px`.
- **Cấu trúc Master-Detail trên `DocumentListPage`:**
  - Trên màn hình rộng ($\ge 720\text{px}$): Cột trái (Master) cố định hiển thị danh sách tài liệu và bộ lọc; Cột phải (Detail) xem trước toàn bộ nội dung tài liệu, môn học và tệp tin đính kèm mà không cần chuyển trang.
  - Trên màn hình di động: Tự động chuyển đổi mượt mà sang danh sách đơn dạng dọc truyền thống.
- **Bố cục thẻ linh hoạt trên `HomePage`:** Tự động co giãn 1 cột trên Mobile hẹp, 2 cột trên Tablet và 3 cột trên Desktop.

### 3. Checklist 03: Phân loại bằng Thẻ Tag & Bản đồ vị trí vật lý tài liệu
- **Gắn thẻ tài liệu thông minh (`TagInputField`):**
  - Nhập Tag dạng Chip tương tác, tự động chuẩn hóa dấu `#`, loại bỏ trùng lặp và khoảng trắng.
  - Cung cấp sẵn các tag phổ biến: `#GiaoTrinh`, `#DeThi`, `#Slide`, `#ThucHanh`, `#Flutter`, `#Firebase`, `#AI`, `#Mobile`.
  - Bộ lọc nhanh bằng thanh cuộn ngang Tag Chip trên màn hình tìm kiếm `DocumentSearchPage`.
- **Định vị vị trí vật lý trên Bản đồ OpenStreetMap:**
  - Hộp thoại chọn vị trí `LocationPickerBottomSheet`: Cho phép bấm trực tiếp lên bản đồ hoặc dùng `geolocator` lấy tọa độ GPS hiện tại, nhập tên vị trí (vd: *"Kệ B3, Thư viện Tạ Quang Bửu"*).
  - Màn hình bản đồ toàn diện `DocumentMapPage`: Ghim các Marker tài liệu học tập trong khuôn viên trường ĐH Thủy Lợi, bấm Marker hiện Card tóm tắt và nút "Xem chi tiết" dẫn vào `DocumentDetailPage`.

### 4. Checklist 04: Luồng nghiệp vụ Mượn / Trả & Chia sẻ tài liệu
- **Cỗ máy trạng thái (State Machine):**
  - `pending` (Chờ chủ sở hữu duyệt) $\rightarrow$ `approved` (Đang mượn) $\rightarrow$ `returned` (Đã trả xong) hoặc `rejected` (Từ chối).
- **Giao diện quản lý 2 chiều (`BorrowManagementPage`):**
  - **Tab 1: Tài liệu tôi đang mượn:** Theo dõi ngày hẹn trả, cảnh báo sắp hết hạn, nút "Báo đã trả".
  - **Tab 2: Yêu cầu mượn gửi tới tôi:** Dành cho chủ tài liệu duyệt hoặc từ chối yêu cầu kèm lý do.
- **Tương tác trực quan:** Nút "Gửi yêu cầu mượn tài liệu" xuất hiện thông minh trên `DocumentDetailPage` khi xem tài liệu của người khác; Badge đếm số yêu cầu mượn đang chờ duyệt nổi bật trên thanh AppBar trang chủ.

### 5. Checklist 05: Thuật toán Gợi ý thông minh (Recommendation Engine)
- **Mô hình tính điểm tương đồng (Content-Based Filtering):**
  $$\text{Score}(doc) = 2.0 \times |\text{Tag trùng}| + 1.5 \times (\text{Trùng môn học quan tâm}) + 1.0 \times (\text{Mức độ ưu tiên cao})$$
- **Khối gợi ý `RecommendedSection`:** Tích hợp trực tiếp trên trang chủ `HomePage` với hiệu ứng bắt mắt, hiển thị huy hiệu lý do gợi ý (Explainable AI: *"Khớp môn Lập trình di động và tag #Flutter"*).
- **Hồ sơ sở thích cá nhân:** Hỗ trợ người dùng lưu các môn học và tag quan tâm trong `AccountProfilePage` và hộp thoại `UserInterestsDialog`.

### 6. Checklist 06: Kiểm thử tự động toàn diện & Đóng gói sản phẩm
- **Kết quả Kiểm thử Tự động (Automated Test Suite):**
  - **87 / 87 bài kiểm thử PASSED 100%**, bao gồm đầy đủ Unit Test, Widget Test, Integration Test và Performance Test dưới mạng yếu.
  - Phân tích mã nguồn (`flutter analyze`): **0 Error, 0 Warning**.
- **Đóng gói sản phẩm:**
  - Web Release Build thành công tại `build/web/`.
  - Android APK sẵn sàng triển khai.

---

## 🔍 KẾT QUẢ ĐỐI CHIẾU PHÂN CÔNG & HOÀN THIỆN TỒN ĐỌNG

Trong quá trình rà soát độc lập và tích hợp mã nguồn (Integration Phase):

1. **Khắc phục lỗi biên dịch và xung đột nhánh (Merge Conflict):**
   - Đã sửa triệt để lỗi cú pháp và trùng lặp mã trong `lib/pages/add_edit_document_page.dart`.
   - Khôi phục đầy đủ danh mục gói phụ thuộc trong `pubspec.yaml` (`connectivity_plus`, `file_picker`, `firebase_storage`, `shared_preferences`, `flutter_map`, `latlong2`, `geolocator`).
2. **Ghép nối toàn diện các tính năng độc lập vào luồng ứng dụng chính:**
   - Đã liên kết `RecommendedSection` (Sơn) vào `HomePage` để hiển thị gợi ý học tập ngay trang đầu.
   - Đã gắn nút truy cập `DocumentMapPage` (Khanh) vào AppBar và bảng điều khiển `HomePage`.
   - Đã hoàn thiện tính năng chọn tọa độ bản đồ vào màn hình thêm/sửa tài liệu `AddEditDocumentPage`.
   - Cập nhật bộ ảnh chụp giao diện kiểm thử nghiệm thu (Golden Screenshots).

---

## 🏁 KẾT LUẬN

Hệ thống **Quản lý Tài liệu Đa nền tảng (study_document_manager)** của Nhóm 12 đã **đáp ứng trọn vẹn 100% tất cả 6 mục Checklist** theo yêu cầu của Giảng viên giao cho Đề tài TH2. Hệ thống hoạt động mượt mà, hỗ trợ cả Online và Offline, có tính năng tương tác mượn trả thời gian thực, bản đồ định vị và gợi ý học tập thông minh.
