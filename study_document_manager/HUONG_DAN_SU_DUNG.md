# 📖 HƯỚNG DẪN CÀI ĐẶT & SỬ DỤNG
## Hệ thống Quản lý Tài liệu Học tập Đa nền tảng - BÀI THỰC HÀNH SỐ 02
> **Dự án:** `study_document_manager` · Flutter + Firebase + Supabase  
> **Nhóm 12** — Lớp 65KTPM — Khoa CNTT, Trường Đại học Thủy Lợi  
> **Cập nhật:** 23/10/2026

---

## MỤC LỤC

1. [Yêu cầu hệ thống](#1-yêu-cầu-hệ-thống)
2. [Cài đặt & Khởi động](#2-cài-đặt--khởi-động)
3. [Các chế độ chạy ứng dụng](#3-các-chế-độ-chạy-ứng-dụng)
4. [Màn hình Trang chủ (Dashboard)](#4-màn-hình-trang-chủ-dashboard)
5. [Quản lý tài liệu (CRUD)](#5-quản-lý-tài-liệu-crud)
6. [Tính năng Gắn thẻ (Tagging)](#6-tính-năng-gắn-thẻ-tagging)
7. [Bản đồ vị trí tài liệu (Map)](#7-bản-đồ-vị-trí-tài-liệu-map)
8. [Luồng Mượn / Trả tài liệu](#8-luồng-mượn--trả-tài-liệu)
9. [Gợi ý tài liệu (Recommendation)](#9-gợi-ý-tài-liệu-recommendation)
10. [Đăng nhập Cloud (Firebase & Supabase)](#10-đăng-nhập-cloud-firebase--supabase)
11. [Kiểm thử Offline với 3 tài khoản mẫu](#11-kiểm-thử-offline-với-3-tài-khoản-mẫu)
12. [Tìm kiếm & Lọc tài liệu](#12-tìm-kiếm--lọc-tài-liệu)
13. [Câu hỏi thường gặp (FAQ)](#13-câu-hỏi-thường-gặp-faq)

---

## 1. Yêu cầu hệ thống

| Thành phần | Phiên bản tối thiểu |
|---|---|
| Flutter SDK | ≥ 3.13.2 |
| Dart SDK | ≥ 3.1.0 |
| Chrome (để chạy Web) | ≥ 110 |
| Android SDK | API 21+ (Android 5.0) |
| Kết nối internet | **Không bắt buộc** (Offline-First) |

---

## 2. Cài đặt & Khởi động

### Bước 1: Clone dự án

```bash
git clone <repository-url>
cd study_document_manager
```

### Bước 2: Cài đặt dependencies

```bash
flutter pub get
```

### Bước 3: Chạy ứng dụng

Xem **Mục 3** để chọn chế độ phù hợp với tình huống của bạn.

---

## 3. Các chế độ chạy ứng dụng

Ứng dụng hỗ trợ **4 cách chạy** tùy tình huống:

---

### 🟢 Chế độ A — Chạy Web (Có mạng internet) ← **Dùng hàng ngày**

```bash
flutter run -d chrome
```

**Kết quả:**
- App tự động khởi tạo Firebase (không cần cờ `--dart-define`)
- Vào thẳng **Trang chủ** mà **không cần đăng nhập**
- Dữ liệu lưu cục bộ (SQLite/In-Memory), sẵn sàng dùng ngay
- Đăng nhập Google/Supabase là **tùy chọn** để bật cloud sync

> **💡 Tip:** Lần đầu chạy sẽ mất ~30s để tải CanvasKit từ CDN. Các lần sau nhanh hơn vì đã cache.

---

### 🟡 Chế độ B — Chạy Web Offline (Không có mạng) ← **Dùng khi demo không có wifi**

```bash
flutter run -d chrome --web-renderer html
```

**Kết quả:**
- Dùng HTML renderer (có sẵn trong trình duyệt), **không cần tải CanvasKit từ internet**
- Chạy được hoàn toàn khi mất mạng
- Đầy đủ tính năng: Tài liệu, Map, Tags, Mượn/Trả, Gợi ý

> **⚠️ Lưu ý:** Font chữ Roboto có thể dùng font dự phòng của hệ thống nếu không có mạng — giao diện vẫn đọc được.

---

### 🔵 Chế độ C — Chạy Web với Port cố định ← **Khuyên dùng để giữ phiên đăng nhập**

```bash
flutter run -d chrome --web-port 8080
```

**Tại sao dùng?**  
Mỗi lần chạy không cố định port, Firebase sẽ coi là "trang web khác" và mất phiên đăng nhập. Cố định port `8080` giúp Firebase nhớ tài khoản đã đăng nhập giữa các lần Ctrl+C → chạy lại.

---

### 🟣 Chế độ D — Serve bản Release (Demo chuyên nghiệp, offline hoàn toàn)

```bash
# Bước 1: Build (chỉ cần làm 1 lần, cần có mạng)
flutter build web --release

# Bước 2: Serve local (không cần mạng)
python -m http.server 8080 --directory build/web
```

Sau đó mở trình duyệt: **`http://localhost:8080`**

**Ưu điểm:**
- CanvasKit và font đã được đóng gói vào `build/web/` — **chạy offline 100%**
- Nhanh hơn debug mode
- Thích hợp để nộp bài hoặc demo trước giảng viên

---

### 📱 Chế độ E — Chạy trên Android

```bash
# Kết nối điện thoại Android (bật Developer Mode + USB Debugging)
flutter run -d android
```

---

## 4. Màn hình Trang chủ (Dashboard)

Trang chủ là màn hình đầu tiên sau khi mở app, hiển thị:

```
┌─────────────────────────────────────┐
│  📊 Tổng quan (4 thẻ thống kê)      │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │ 5  │ │ 2  │ │ 1  │ │Bản │       │
│  │Tài │ │Hoàn│ │Đang│ │đồ  │       │
│  │liệu│ │thành│ │mượn│ │    │       │
│  └────┘ └────┘ └────┘ └────┘       │
│                                     │
│  ✨ Gợi ý cho bạn hôm nay           │
│  [Card tài liệu 1] [Card TL 2]...  │
│                                     │
│  📚 Tài liệu gần đây               │
│  [Danh sách tài liệu]               │
└─────────────────────────────────────┘
```

**Các thao tác từ Trang chủ:**

| Phần tử | Thao tác | Kết quả |
|---|---|---|
| Nút **+** (góc phải) | Nhấn | Mở form thêm tài liệu mới |
| Thẻ **Bản đồ** | Nhấn | Mở trang bản đồ toàn màn hình |
| Card gợi ý | Nhấn | Xem chi tiết tài liệu được gợi ý |
| Tài liệu gần đây | Nhấn | Xem chi tiết tài liệu |
| Biểu tượng 🔔 (AppBar) | Nhấn | Xem thông báo yêu cầu mượn |

---

## 5. Quản lý tài liệu (CRUD)

### 5.1 Xem danh sách tài liệu

- Nhấn tab **"Tài liệu"** ở thanh điều hướng dưới cùng
- Danh sách hiển thị tất cả tài liệu của tài khoản hiện tại
- **Lọc nhanh:** Nhấn các chip lọc ở đầu danh sách (Tất cả / Bài giảng / Bài tập / Đề thi / Tài liệu tham khảo)

### 5.2 Thêm tài liệu mới

1. Nhấn nút **`+`** (FloatingActionButton) màu xanh
2. Điền thông tin trong form:

| Trường | Mô tả | Bắt buộc |
|---|---|---|
| **Tiêu đề** | Tên tài liệu | ✅ |
| **Môn học** | Chọn từ danh sách môn học | ✅ |
| **Loại tài liệu** | Bài giảng / Bài tập / Đề thi / Tham khảo | ✅ |
| **Tags (thẻ)** | Nhập và bấm Enter để thêm tag | ❌ |
| **Mức độ ưu tiên** | Thấp / Trung bình / Cao | ❌ |
| **Trạng thái** | Chưa bắt đầu / Đang làm / Hoàn thành | ❌ |
| **Hạn nộp** | Chọn ngày deadline | ❌ |
| **Vị trí vật lý** | Nhấn "Chọn vị trí trên bản đồ" | ❌ |
| **URL / File đính kèm** | Link hoặc tải file lên | ❌ |
| **Ghi chú** | Nội dung mô tả thêm | ❌ |

3. Nhấn **"Lưu tài liệu"**

### 5.3 Sửa tài liệu

1. Mở chi tiết tài liệu (nhấn vào tài liệu trong danh sách)
2. Nhấn biểu tượng ✏️ (bút chì) ở góc phải trên
3. Chỉnh sửa các trường → Nhấn **"Cập nhật"**

> **⚠️ Lưu ý phân quyền:** Chỉ **chủ sở hữu** mới được sửa. Người được chia sẻ quyền `viewer` **không thể sửa**.

### 5.4 Xóa tài liệu

1. Mở chi tiết tài liệu
2. Nhấn biểu tượng 🗑️ (thùng rác)
3. Xác nhận xóa trong hộp thoại

> **⚠️ Lưu ý:** Chỉ chủ sở hữu mới thấy nút xóa.

### 5.5 Đánh dấu yêu thích ⭐

- Trong chi tiết tài liệu → Nhấn biểu tượng ⭐
- Tài liệu yêu thích xuất hiện ở đầu danh sách

---

## 6. Tính năng Gắn thẻ (Tagging)

Tags giúp phân loại và tìm kiếm tài liệu nhanh hơn.

### 6.1 Thêm tag vào tài liệu

Trong form thêm/sửa tài liệu, phần **"Tags"**:
1. Nhập tên tag vào ô (ví dụ: `Flutter`)
2. Bấm **Enter** hoặc **dấu phẩy (,)** để tạo chip tag
3. Nhấn **✕** trên chip để xóa tag

**Các tag gợi ý phổ biến:**

| Tag | Ý nghĩa |
|---|---|
| `#Flutter` | Tài liệu về Flutter |
| `#Firebase` | Liên quan đến Firebase |
| `#Supabase` | Liên quan đến Supabase |
| `#GiaoTrinh` | Sách giáo trình |
| `#DeThi` | Đề thi / đề cương |
| `#Slide` | File slide bài giảng |
| `#AI` | Trí tuệ nhân tạo |
| `#Mobile` | Lập trình di động |

### 6.2 Lọc theo tag

- Trên trang **Tìm kiếm**: Nhấn chip tag để lọc tất cả tài liệu có tag đó
- Có thể chọn nhiều tag cùng lúc (lọc giao — AND)

---

## 7. Bản đồ vị trí tài liệu (Map)

Tính năng bản đồ giúp quản lý vị trí vật lý của tài liệu trong khuôn viên trường.

### 7.1 Mở bản đồ

- Từ **Trang chủ** → Nhấn thẻ 🗺️ **"Bản đồ"**
- Hoặc nhấn biểu tượng bản đồ trên AppBar

### 7.2 Đọc bản đồ

```
🔴 Marker đỏ  = Tài liệu vật lý (sách/giáo trình thật)
🔵 Marker xanh = Tài liệu số (file PDF, link)
```

- **Nhấn vào Marker** → Hiện thẻ thông tin tóm tắt (tên tài liệu, môn học, trạng thái mượn)
- **Nhấn "Xem chi tiết"** → Chuyển sang trang chi tiết tài liệu

### 7.3 Gắn vị trí cho tài liệu

Khi thêm/sửa tài liệu:
1. Kéo xuống phần **"Vị trí vật lý"**
2. Nhấn **"Chọn vị trí trên bản đồ"**
3. Trong bản đồ Bottom Sheet:
   - **Nhấn vào bản đồ** để ghim tọa độ
   - Hoặc nhấn **"📍 Lấy vị trí hiện tại"** (cần cấp quyền GPS)
4. Nhập **tên mô tả vị trí** (ví dụ: *"Thư viện ĐH Thủy Lợi - Tầng 2, Kệ C-12"*)
5. Nhấn **"Xác nhận vị trí"**

**Ví dụ vị trí trong khuôn viên ĐH Thủy Lợi:**

| Vị trí | Tọa độ tham khảo |
|---|---|
| Thư viện ĐH Thủy Lợi | 21.00745, 105.82472 |
| Giảng đường T35 | 21.00775, 105.82520 |
| Nhà A1 (Phòng đọc sách) | 21.00700, 105.82442 |
| Văn phòng Khoa CNTT | 21.00825, 105.82412 |

---

## 8. Luồng Mượn / Trả tài liệu

Đây là tính năng cho phép sinh viên mượn tài liệu của nhau.

### 8.1 Vòng đời trạng thái mượn

```
[Gửi yêu cầu] → ⏳ Chờ duyệt → ✅ Đang mượn → 📦 Đã trả
                              ↘ ❌ Bị từ chối
```

### 8.2 Gửi yêu cầu mượn tài liệu (Bên mượn)

1. Tìm tài liệu muốn mượn (tìm kiếm hoặc xem bản đồ)
2. Mở trang **Chi tiết tài liệu**
3. Nếu tài liệu thuộc người khác → xuất hiện nút **"📤 Gửi yêu cầu mượn"**
4. Nhấn nút → Điền vào hộp thoại:
   - **Ngày hẹn trả** (bắt buộc)
   - **Lý do / Ghi chú** (tùy chọn, ví dụ: *"Mình mượn để ôn thi cuối kỳ"*)
5. Nhấn **"Gửi yêu cầu"**

→ Chủ sở hữu sẽ nhận được thông báo ngay lập tức.

### 8.3 Duyệt/Từ chối yêu cầu (Bên cho mượn — Chủ sở hữu)

1. Nhấn tab **"Mượn/Chia sẻ"** ở thanh điều hướng (hoặc biểu tượng 🔔)
2. Chuyển sang **Tab "Yêu cầu tới tôi"**
3. Xem danh sách yêu cầu đang chờ duyệt
4. Nhấn **"✅ Cho mượn"** hoặc **"❌ Từ chối"**

### 8.4 Xem tài liệu đang mượn (Bên mượn)

1. Nhấn tab **"Mượn/Chia sẻ"**
2. Tab **"Tài liệu tôi đang mượn"** hiển thị:
   - Danh sách tài liệu đã được duyệt
   - Ngày hẹn trả, cảnh báo nếu sắp quá hạn
   - Nút **"📦 Báo đã trả"** khi hoàn trả xong

### 8.5 Kịch bản kiểm thử nhanh (Không cần mạng)

Dùng 3 tài khoản demo sẵn có trong tab **"Kiểm thử Offline"**:

```
👩‍🎓 Alice  →  gửi yêu cầu mượn Slide Flutter của chính mình (demo owner)
👨‍🎓 Bob    →  đang chờ duyệt mượn Slide Flutter từ Alice
🧑‍🎓 Charlie →  đã được duyệt mượn Đề thi DSA từ Alice
```

**4 bước thực hiện:**
1. **Đăng nhập Alice** → Vào tab "Mượn/Chia sẻ" → xem 2 yêu cầu đang chờ
2. **Duyệt yêu cầu của Bob** → Nhấn "Cho mượn"
3. **Chuyển sang Bob** → Xem Slide Flutter đã xuất hiện trong "Tài liệu đang mượn"
4. **Chuyển sang Charlie** → Xem Đề thi DSA (đã được duyệt trước) + gợi ý tài liệu AI

---

## 9. Gợi ý tài liệu (Recommendation)

Thuật toán gợi ý tự động đề xuất tài liệu phù hợp dựa trên sở thích của bạn.

### 9.1 Thuật toán hoạt động như thế nào?

```
Score(tài liệu) = 
  2.0 × (số tag trùng với sở thích) +
  1.5 × (trùng môn học quan tâm) +
  1.0 × (độ ưu tiên cao) +
  0.5 × (tài liệu yêu thích)
```

→ Top 5 tài liệu điểm cao nhất được hiển thị trên Trang chủ với **lý do gợi ý** cụ thể.

### 9.2 Cài đặt sở thích cá nhân

**Cách 1:** Từ trang Tài khoản
1. Nhấn tab **"Tài khoản"** ở thanh điều hướng
2. Nhấn **"⚡ Hồ sơ cá nhân"**
3. Cuộn xuống phần **"Sở thích & Tags quan tâm"**
4. Tick chọn các tag và môn học yêu thích → **"Lưu"**

**Cách 2:** Từ tab "Kiểm thử Offline"
1. Tab **"Tài khoản"** → Tab **"Kiểm thử Offline"**
2. Nhấn **"⚡ Cài đặt sở thích gợi ý"**
3. Chọn tags quan tâm trong hộp thoại

### 9.3 Xem gợi ý

- **Trang chủ** → Section **"✨ Gợi ý cho bạn hôm nay"**
- Mỗi card gợi ý hiển thị badge lý do (ví dụ: *"Vì bạn quan tâm #Flutter"*)

---

## 10. Đăng nhập Cloud (Firebase & Supabase)

> **Lưu ý quan trọng:** Đăng nhập cloud là **HOÀN TOÀN TÙY CHỌN**. App chạy đầy đủ tính năng mà không cần đăng nhập.

### 10.1 Khi nào cần đăng nhập?

| Tính năng | Offline (không đăng nhập) | Online (đã đăng nhập) |
|---|---|---|
| Xem/Thêm/Sửa/Xóa tài liệu | ✅ | ✅ |
| Tags & Bản đồ | ✅ | ✅ |
| Mượn/Trả tài liệu (cùng thiết bị) | ✅ | ✅ |
| Gợi ý tài liệu | ✅ | ✅ |
| **Đồng bộ đa thiết bị** | ❌ | ✅ |
| **Mượn tài liệu giữa các máy khác nhau** | ❌ | ✅ |
| **Upload file lên Cloud Storage** | ❌ | ✅ |
| **Thông báo realtime** | ❌ | ✅ |

### 10.2 Đăng nhập Firebase (Google Sign-In)

1. Nhấn tab **"Tài khoản"** → Tab **"Firebase Google"**
2. Nhấn **"Đăng nhập với Google"**
3. Chọn tài khoản Google trong popup
4. Xác nhận → **Đã đăng nhập** ✅

> **Phiên đăng nhập được lưu tự động.** Từ lần sau chạy `flutter run -d chrome --web-port 8080`, bạn **không cần đăng nhập lại**.

### 10.3 Đăng nhập Supabase (Email/Password)

1. Nhấn tab **"Tài khoản"** → Tab **"Supabase Cloud"**
2. Nhập **Supabase URL** và **Anon Key** của project (lấy từ Supabase Dashboard)
3. Nhấn **"Kết nối Supabase"**
4. Đăng nhập bằng email/password đã đăng ký trên Supabase

### 10.4 Đăng xuất

- Tab **"Tài khoản"** → Tab tương ứng → Nút **"Đăng xuất"**
- App sẽ tiếp tục hoạt động ở chế độ offline sau khi đăng xuất

---

## 11. Kiểm thử Offline với 3 tài khoản mẫu

Tab này phục vụ demo và chấm bài — không cần mạng, không cần tài khoản thật.

### 11.1 Truy cập

Tab **"Tài khoản"** → Tab **"Kiểm thử Offline"**

### 11.2 Ba hồ sơ sinh viên demo

| Hồ sơ | ID đăng nhập | Vai trò | Dữ liệu có sẵn |
|---|---|---|---|
| 👩‍🎓 **Alice Nguyễn** | `local` (mặc định) | Chủ sở hữu 5 tài liệu | Nhận 2 yêu cầu mượn từ Bob & Charlie |
| 👨‍🎓 **Bob Trần** | `bob@tlu.edu.vn` | Người mượn (chờ duyệt) | Yêu cầu mượn Slide Flutter đang chờ |
| 🧑‍🎓 **Charlie Lê** | `charlie@tlu.edu.vn` | Người mượn (đã duyệt) | Đề thi DSA đã được duyệt |

### 11.3 Chuyển tài khoản

1. Nhìn 3 thẻ hồ sơ sinh viên
2. Nhấn **"Chuyển sang [Tên]"** trên thẻ muốn chuyển
3. App cập nhật tức thì — dữ liệu hiển thị theo tài khoản mới
4. Thẻ đang active có viền xanh + badge **"✓ Đang dùng"**

---

## 12. Tìm kiếm & Lọc tài liệu

### 12.1 Tìm kiếm

1. Nhấn biểu tượng 🔍 trên AppBar (hoặc tab Tìm kiếm)
2. Gõ từ khóa — tìm theo: tiêu đề, ghi chú, tên môn học, tags

### 12.2 Bộ lọc nâng cao

Trên trang tìm kiếm, có các bộ lọc:

| Bộ lọc | Tùy chọn |
|---|---|
| Loại tài liệu | Tất cả / Bài giảng / Bài tập / Đề thi / Tham khảo |
| Trạng thái | Tất cả / Chưa bắt đầu / Đang làm / Hoàn thành |
| Độ ưu tiên | Tất cả / Thấp / Trung bình / Cao |
| Môn học | Chọn từ danh sách |
| Tag | Nhấn chip tag để lọc |

### 12.3 Sắp xếp

- Mới nhất → Cũ nhất
- Cũ nhất → Mới nhất
- Theo tiêu đề A-Z
- Theo độ ưu tiên

---

## 13. Câu hỏi thường gặp (FAQ)

### ❓ Mỗi lần chạy lại có phải đăng nhập Google không?

**Không.** Firebase tự lưu phiên đăng nhập. Chỉ cần đăng nhập 1 lần.  
Để giữ phiên ổn định: dùng `--web-port 8080` để cố định port.

### ❓ App bị lỗi "Failed to fetch canvaskit.js" khi không có mạng?

Đây là lỗi Flutter Web debug mode cần tải CanvasKit từ CDN.  
**Giải pháp:** Dùng HTML renderer: `flutter run -d chrome --web-renderer html`

### ❓ Tại sao app có 2 chỗ đăng nhập (Firebase và Supabase)?

Yêu cầu TH2 (Checklist 01) đòi hỏi kết hợp **Firebase** (Authentication + Messaging) và **Supabase** (Database PostgreSQL + Storage). Mỗi dịch vụ đảm nhận vai trò riêng:
- **Firebase Auth** → Xác thực người dùng bằng Google (OAuth2)
- **Supabase** → Lưu trữ dữ liệu tài liệu, borrow requests, đồng bộ realtime

Bạn không cần đăng nhập cả 2 — chỉ cần 1 trong 2 (hoặc không cần cả hai nếu dùng offline).

### ❓ Dữ liệu lưu ở đâu khi chạy offline?

- **Web:** Lưu trong bộ nhớ In-Memory (mất khi đóng tab) + IndexedDB/SQLite Web
- **Android/iOS:** Lưu vào SQLite cục bộ trong thiết bị (không bị mất)

### ❓ Làm sao để reset về dữ liệu mẫu ban đầu?

- **Web:** Đóng tab Chrome → Mở lại → App tự load dữ liệu mẫu
- **Android:** Xóa dữ liệu ứng dụng trong Cài đặt → Ứng dụng

### ❓ App có hỗ trợ tablet và màn hình lớn không?

**Có.** Giao diện tự động thích ứng (Responsive):
- **Mobile (< 600px):** NavigationBar ở dưới cùng, 1 cột
- **Tablet (600-1024px):** NavigationRail ở bên trái, 2 cột
- **Desktop/Web (> 1024px):** Sidebar cố định, layout Master-Detail

---

## 📋 Phím tắt & Mẹo

| Thao tác | Hướng dẫn |
|---|---|
| Thêm tài liệu nhanh | Nhấn nút **`+`** màu xanh bất kỳ trang nào |
| Yêu thích | Nhấn ⭐ trong chi tiết tài liệu |
| Đánh dấu hoàn thành | Vuốt sang phải trong danh sách (hoặc sửa Trạng thái) |
| Xem bản đồ | Nhấn thẻ "Bản đồ" trên Trang chủ |
| Gợi ý mới | Cập nhật sở thích trong Hồ sơ cá nhân |
| Chuyển tài khoản demo | Tab Tài khoản → Kiểm thử Offline → Chọn hồ sơ |

---

*Tài liệu được cập nhật bởi Nhóm 12 — Trường Đại học Thủy Lợi — 10/2026*
