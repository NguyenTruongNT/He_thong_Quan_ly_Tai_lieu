# HƯỚNG DẪN TÍNH NĂNG MAP & TAGGING

> **Người thực hiện:** Vũ Tuấn Khanh  
> **Vai trò:** Map & Tagging Engineer  
> **Checklist phụ trách:** Checklist 03  
> **Nhánh Git:** `khanh-map-tagging`  
> **Dự án:** `study_document_manager`  
> **Học phần:** Phát triển Ứng dụng Đa nền tảng  
> **Nhóm:** Nhóm 12  

---

## 1. Mục tiêu thực hiện

Phần Map & Tagging được xây dựng nhằm bổ sung hai nhóm chức năng chính cho hệ thống quản lý tài liệu:

1. Gắn thẻ phân loại cho tài liệu bằng giao diện Tag Chip.
2. Quản lý và hiển thị vị trí vật lý của tài liệu trên bản đồ tương tác.

Các chức năng được phát triển theo hướng độc lập bằng Mock Data. Vì vậy, giao diện và nghiệp vụ có thể chạy thử mà không phải chờ hoàn thiện Supabase, SQLite Migration hoặc SyncEngine.

Khi tích hợp với source chính, Mock Data sẽ được thay thế bằng dữ liệu thật từ `DocumentService` hoặc tầng Repository.

---

## 2. Phạm vi công việc đã thực hiện

### 2.1. Hệ thống gắn thẻ tài liệu

Đã xây dựng widget `TagInputField` với các chức năng:

- Nhập Tag bằng bàn phím.
- Nhấn Enter để tạo Tag.
- Nhập nhiều Tag bằng dấu phẩy.
- Tự động thêm ký tự `#` nếu người dùng chưa nhập.
- Loại bỏ khoảng trắng trong Tag.
- Ngăn tạo Tag trùng lặp.
- So sánh Tag không phân biệt chữ hoa và chữ thường.
- Xóa từng Tag bằng nút đóng trên Input Chip.
- Giới hạn tối đa số lượng Tag.
- Hiển thị danh sách Tag phổ biến.
- Chọn hoặc bỏ chọn Tag gợi ý bằng `FilterChip`.
- Trả danh sách Tag mới về màn hình cha thông qua callback `onChanged`.

Các Tag gợi ý mặc định gồm:

```text
#GiaoTrinh
#DeThi
#Slide
#ThucHanh
#Flutter
#Firebase
#AI
#Mobile
```

### 2.2. Bản đồ vị trí tài liệu

Đã tích hợp bản đồ OpenStreetMap thông qua thư viện `flutter_map`.

Các chức năng đã xây dựng:

- Hiển thị bản đồ tương tác.
- Phóng to và thu nhỏ bản đồ.
- Di chuyển bản đồ.
- Hiển thị Marker theo tọa độ tài liệu.
- Sử dụng màu Marker để phân biệt tài liệu.
- Hiển thị trạng thái tài liệu đang có sẵn hoặc đang được mượn.
- Bấm Marker để xem Card tóm tắt.
- Hiển thị tiêu đề tài liệu.
- Hiển thị môn học.
- Hiển thị vị trí vật lý.
- Hiển thị tọa độ.
- Hiển thị danh sách Tag.
- Hiển thị tình trạng mượn.
- Hiển thị nút `Xem chi tiết`.
- Lọc Marker theo Tag.
- Hiển thị số lượng tài liệu sau khi lọc.
- Hiển thị thông báo khi không có tài liệu phù hợp.

### 2.3. Chọn vị trí tài liệu

Đã xây dựng `LocationPickerBottomSheet` với các chức năng:

- Mở bản đồ trong Bottom Sheet.
- Bấm trực tiếp lên bản đồ để chọn tọa độ.
- Hiển thị Marker tại tọa độ đã chọn.
- Nhập tên hoặc mô tả vị trí.
- Hiển thị kinh độ và vĩ độ.
- Xác nhận vị trí.
- Hủy thao tác chọn vị trí.
- Lấy vị trí hiện tại bằng `geolocator`.
- Kiểm tra trạng thái dịch vụ vị trí.
- Yêu cầu quyền truy cập vị trí.
- Xử lý trường hợp người dùng từ chối quyền.
- Xử lý trường hợp quyền bị từ chối vĩnh viễn.
- Xử lý trường hợp lấy vị trí quá thời gian.
- Tự động di chuyển bản đồ tới vị trí hiện tại.
- Hiển thị tiến trình khi đang lấy vị trí.

---

## 3. Thư viện sử dụng

Các thư viện chính được bổ sung vào `pubspec.yaml`:

```yaml
dependencies:
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: any
```

### 3.1. `flutter_map`

Được sử dụng để:

- Hiển thị bản đồ OpenStreetMap.
- Quản lý `TileLayer`.
- Hiển thị `MarkerLayer`.
- Điều khiển bản đồ bằng `MapController`.
- Bắt sự kiện bấm lên bản đồ.
- Hiển thị thông tin nguồn dữ liệu bản đồ.

### 3.2. `latlong2`

Được sử dụng để:

- Biểu diễn tọa độ bằng `LatLng`.
- Lưu kinh độ và vĩ độ.
- Truyền tọa độ cho Marker và Map Controller.

### 3.3. `geolocator`

Được sử dụng để:

- Kiểm tra dịch vụ vị trí.
- Kiểm tra quyền truy cập vị trí.
- Yêu cầu quyền truy cập.
- Lấy vị trí hiện tại của thiết bị.
- Mở phần cài đặt quyền khi cần thiết.

---

## 4. Các file đã tạo

### 4.1. Model phục vụ bản đồ

```text
lib/models/map_document_item.dart
```

File này định nghĩa `MapDocumentItem`, gồm các thuộc tính:

```dart
String id;
String title;
String subjectName;
String locationName;
double latitude;
double longitude;
List<String> tags;
bool isBorrowed;
Color markerColor;
```

`MapDocumentItem` là model trung gian phục vụ phát triển độc lập.

Model này không thay thế `DocumentModel` chính. Khi tích hợp, dữ liệu từ `DocumentModel` sẽ được chuyển đổi sang `MapDocumentItem`.

### 4.2. Dữ liệu Mock

```text
lib/mock/mock_documents_with_location.dart
```

File chứa các tài liệu mẫu phục vụ kiểm thử độc lập.

Mỗi tài liệu Mock gồm:

- ID.
- Tiêu đề.
- Môn học.
- Tên vị trí.
- Kinh độ.
- Vĩ độ.
- Danh sách Tag.
- Trạng thái mượn.
- Màu Marker.

Các vị trí được thiết kế để mô phỏng tài liệu nằm tại những khu vực khác nhau trong khuôn viên trường hoặc thư viện.

### 4.3. Widget nhập Tag

```text
lib/widgets/tags/tag_input_field.dart
```

Class chính:

```dart
TagInputField
```

Callback trả dữ liệu:

```dart
ValueChanged<List<String>> onChanged
```

Các tham số chính:

```dart
List<String> initialTags;
List<String> suggestions;
int maxTags;
```

### 4.4. Widget bản đồ tài liệu

```text
lib/widgets/map/document_map_widget.dart
```

Class chính:

```dart
DocumentMapWidget
```

Widget nhận:

```dart
List<MapDocumentItem> documents;
ValueChanged<MapDocumentItem> onDocumentSelected;
LatLng initialCenter;
double initialZoom;
```

### 4.5. Widget chọn vị trí

```text
lib/widgets/map/location_picker_bottom_sheet.dart
```

Các class chính:

```dart
LocationSelection
LocationPickerBottomSheet
```

Kết quả trả về sau khi xác nhận:

```dart
LocationSelection(
  latitude: ...,
  longitude: ...,
  locationName: ...,
)
```

### 4.6. Trang bản đồ tài liệu

```text
lib/pages/document_map_page.dart
```

Class chính:

```dart
DocumentMapPage
```

Trang này:

- Hiển thị toàn bộ tài liệu có vị trí.
- Hiển thị Marker.
- Lọc Marker theo Tag.
- Hiển thị Card tài liệu.
- Hiển thị nút `Xem chi tiết`.

### 4.7. File Demo độc lập

```text
lib/map_tagging_demo.dart
```

File này có hàm `main()` riêng, được sử dụng để chạy thử phần Map & Tagging mà không phải sửa `lib/main.dart`.

Lệnh chạy:

```bash
flutter run -d chrome -t lib/map_tagging_demo.dart
```

---

## 5. Các file đã chỉnh sửa

### 5.1. `pubspec.yaml`

Đã bổ sung:

```yaml
flutter_map: ^7.0.2
latlong2: ^0.9.1
geolocator: any
```

### 5.2. `add_edit_document_page.dart`

Đường dẫn:

```text
lib/pages/add_edit_document_page.dart
```

Đã thay ô nhập Tag dạng chuỗi bằng:

```dart
TagInputField(
  initialTags: _selectedTags,
  onChanged: (List<String> tags) {
    _selectedTags = List<String>.from(tags);
  },
)
```

Dữ liệu Tag được lưu trực tiếp dưới dạng:

```dart
List<String>
```

Các Tag được chuẩn hóa trước khi lưu:

- Loại bỏ Tag rỗng.
- Tự động thêm ký tự `#`.
- Loại bỏ Tag trùng.
- So sánh không phân biệt chữ hoa và chữ thường.

### 5.3. `document_search_page.dart`

Đường dẫn:

```text
lib/pages/document_search_page.dart
```

Đã bổ sung:

- Danh sách Tag phổ biến.
- Thanh Tag Chip cuộn ngang.
- Lọc tài liệu theo Tag.
- Kết hợp lọc Tag với từ khóa.
- Kết hợp lọc Tag với môn học.
- Kết hợp lọc Tag với loại tài liệu.
- Kết hợp lọc Tag với trạng thái yêu thích.
- Nút bỏ lọc Tag.
- Nút xóa toàn bộ bộ lọc.
- Thông báo khi không có tài liệu phù hợp với Tag.

### 5.4. `AndroidManifest.xml`

Đường dẫn:

```text
android/app/src/main/AndroidManifest.xml
```

Đã bổ sung quyền:

```xml
<uses-permission android:name="android.permission.INTERNET" />

<uses-permission
    android:name="android.permission.ACCESS_COARSE_LOCATION" />

<uses-permission
    android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Các quyền trên phục vụ việc:

- Tải bản đồ OpenStreetMap.
- Lấy vị trí gần đúng.
- Lấy vị trí chính xác.

Ứng dụng không yêu cầu quyền vị trí nền vì chức năng chỉ lấy vị trí khi người dùng đang sử dụng màn hình chọn vị trí.

---

## 6. Data Contract áp dụng

Phần Map & Tagging tuân thủ Data Contract của nhóm:

```dart
double? latitude;
double? longitude;
String? locationName;
bool isPhysical;
List<String> tags;
```

Ý nghĩa:

| Thuộc tính | Kiểu dữ liệu | Ý nghĩa |
|---|---|---|
| `latitude` | `double?` | Vĩ độ của vị trí tài liệu |
| `longitude` | `double?` | Kinh độ của vị trí tài liệu |
| `locationName` | `String?` | Tên hoặc mô tả vị trí vật lý |
| `isPhysical` | `bool` | Phân biệt tài liệu vật lý và tài liệu số |
| `tags` | `List<String>` | Danh sách Tag phân loại |

Trong giai đoạn Mock, tọa độ được lưu trong `MapDocumentItem`.

Khi nhóm trưởng hoàn thiện `DocumentModel`, các giá trị được chuyển trực tiếp vào `DocumentModel` thật.

---

## 7. Luồng xử lý Tag

Luồng tạo Tag:

```text
Người dùng nhập nội dung
        ↓
Nhấn Enter hoặc nhập dấu phẩy
        ↓
Loại bỏ khoảng trắng
        ↓
Tự động bổ sung ký tự #
        ↓
Kiểm tra Tag trùng
        ↓
Kiểm tra giới hạn số lượng
        ↓
Hiển thị InputChip
        ↓
Gọi callback onChanged
        ↓
Trang thêm/sửa lưu List<String>
```

Ví dụ:

```text
Dữ liệu nhập:
Flutter, Firebase, Mobile

Dữ liệu sau chuẩn hóa:
#Flutter
#Firebase
#Mobile
```

Nếu người dùng nhập lại:

```text
flutter
```

hệ thống so sánh không phân biệt chữ hoa và chữ thường, nên không tạo thêm Tag trùng với:

```text
#Flutter
```

---

## 8. Luồng chọn vị trí

Luồng chọn vị trí thủ công:

```text
Mở LocationPickerBottomSheet
        ↓
Nhập tên vị trí
        ↓
Bấm lên bản đồ
        ↓
Tạo Marker
        ↓
Hiển thị tọa độ
        ↓
Nhấn Xác nhận vị trí
        ↓
Trả về LocationSelection
```

Luồng lấy vị trí hiện tại:

```text
Bấm Lấy vị trí hiện tại
        ↓
Kiểm tra dịch vụ vị trí
        ↓
Kiểm tra quyền
        ↓
Yêu cầu quyền nếu cần
        ↓
Lấy Position từ Geolocator
        ↓
Chuyển Position thành LatLng
        ↓
Di chuyển bản đồ
        ↓
Hiển thị Marker
        ↓
Xác nhận vị trí
```

---

## 9. Luồng hiển thị bản đồ tài liệu

```text
Danh sách MapDocumentItem
        ↓
DocumentMapWidget
        ↓
Chuyển latitude và longitude thành LatLng
        ↓
Tạo Marker
        ↓
Người dùng bấm Marker
        ↓
Gọi onDocumentSelected
        ↓
DocumentMapPage hiển thị Card tóm tắt
        ↓
Người dùng bấm Xem chi tiết
```

Ở bản Mock, nút `Xem chi tiết` hiển thị `SnackBar`.

Khi tích hợp source chính, callback cần điều hướng tới:

```dart
DocumentDetailPage(
  documentId: document.id,
)
```

---

## 10. Lọc tài liệu theo Tag

Việc so sánh Tag sử dụng dạng chuẩn hóa:

```dart
#flutter
#firebase
#mobile
```

Do đó, các giá trị sau được coi là giống nhau:

```text
Flutter
#Flutter
#flutter
 flutter
```

Luồng lọc:

```text
Người dùng chọn FilterChip
        ↓
Lưu Tag đang chọn
        ↓
Duyệt danh sách tài liệu
        ↓
Chuẩn hóa từng Tag của tài liệu
        ↓
So sánh với Tag đã chọn
        ↓
Hiển thị các Marker phù hợp
```

---

## 11. OpenStreetMap Attribution

Ứng dụng sử dụng Tile URL:

```text
https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

Widget bản đồ có khai báo:

```dart
userAgentPackageName:
    'vn.edu.tlu.study_document_manager'
```

Nguồn dữ liệu bản đồ được hiển thị bằng:

```dart
RichAttributionWidget(
  attributions: const <SourceAttribution>[
    TextSourceAttribution(
      'OpenStreetMap contributors',
    ),
  ],
)
```

Ứng dụng không sử dụng cơ chế tải hàng loạt Tile hoặc lưu Tile để sử dụng ngoại tuyến.

---

## 12. Cách chạy Demo độc lập

Mở Terminal tại:

```text
study_document_manager
```

Cài dependencies:

```bash
flutter pub get
```

Kiểm tra code:

```bash
flutter analyze
```

Chạy trên Chrome:

```bash
flutter run -d chrome -t lib/map_tagging_demo.dart
```

Nếu muốn dùng cổng cố định:

```bash
flutter run -d chrome --web-port 8080 \
  -t lib/map_tagging_demo.dart
```

Kiểm tra danh sách thiết bị:

```bash
flutter devices
```

Chạy trên Android:

```bash
flutter run -d DEVICE_ID \
  -t lib/map_tagging_demo.dart
```

Thay `DEVICE_ID` bằng ID hiển thị từ `flutter devices`.

---

## 13. Các kịch bản kiểm thử

### MT-01: Nhập một Tag bằng Enter

**Các bước:**

1. Mở Demo.
2. Nhập `Flutter`.
3. Nhấn Enter.

**Kết quả mong đợi:**

```text
#Flutter
```

được hiển thị dưới dạng Input Chip.

### MT-02: Nhập nhiều Tag bằng dấu phẩy

**Các bước:**

1. Nhập:
   ```text
   Firebase, Mobile, Slide
   ```
2. Nhấn Enter hoặc kết thúc bằng dấu phẩy.

**Kết quả mong đợi:**

```text
#Firebase
#Mobile
#Slide
```

được tạo thành ba Input Chip riêng biệt.

### MT-03: Ngăn Tag trùng

**Các bước:**

1. Đã có Tag `#Flutter`.
2. Nhập lại `flutter`.

**Kết quả mong đợi:**

Chỉ có một Tag `#Flutter`.

### MT-04: Xóa Tag

**Các bước:**

1. Bấm nút đóng trên Input Chip.

**Kết quả mong đợi:**

Tag được xóa khỏi danh sách và callback `onChanged` trả về dữ liệu mới.

### MT-05: Chọn Tag gợi ý

**Các bước:**

1. Bấm `#GiaoTrinh`.

**Kết quả mong đợi:**

Tag được thêm vào danh sách.

Bấm lại Tag đã chọn sẽ bỏ Tag khỏi danh sách.

### MT-06: Chọn vị trí thủ công

**Các bước:**

1. Mở Location Picker.
2. Nhập tên vị trí.
3. Bấm một điểm trên bản đồ.
4. Bấm `Xác nhận vị trí`.

**Kết quả mong đợi:**

- Marker xuất hiện.
- Tọa độ được hiển thị.
- `LocationSelection` được trả về màn hình trước.

### MT-07: Lấy vị trí hiện tại

**Các bước:**

1. Mở Location Picker.
2. Bấm `Lấy vị trí hiện tại`.
3. Chấp nhận quyền vị trí.

**Kết quả mong đợi:**

- Hiển thị trạng thái đang tải.
- Bản đồ di chuyển tới vị trí thiết bị.
- Marker xuất hiện.
- Tên vị trí mặc định là `Vị trí hiện tại của tôi`.

### MT-08: Hiển thị Marker tài liệu

**Các bước:**

1. Mở bản đồ tài liệu mẫu.

**Kết quả mong đợi:**

- Có 5 Marker tương ứng với 5 tài liệu Mock.
- Mỗi Marker có màu theo tài liệu.
- Tài liệu đang được mượn sử dụng biểu tượng khác.

### MT-09: Xem Card Marker

**Các bước:**

1. Bấm một Marker.

**Kết quả mong đợi:**

Card hiển thị:

- Tiêu đề.
- Môn học.
- Tên vị trí.
- Tọa độ.
- Tag.
- Tình trạng mượn.
- Nút `Xem chi tiết`.

### MT-10: Lọc bản đồ theo Tag

**Các bước:**

1. Chọn `#Flutter`.

**Kết quả mong đợi:**

Chỉ các tài liệu có Tag `#Flutter` được hiển thị.

### MT-11: Tích hợp Tag vào trang thêm tài liệu

**Các bước:**

1. Mở trang thêm tài liệu.
2. Nhập Tag.
3. Lưu tài liệu.
4. Mở lại tài liệu.

**Kết quả mong đợi:**

Danh sách Tag đã lưu được hiển thị lại đúng.

### MT-12: Lọc Tag trong trang tìm kiếm

**Các bước:**

1. Tạo nhiều tài liệu với các Tag khác nhau.
2. Mở trang tìm kiếm.
3. Chọn một Tag.

**Kết quả mong đợi:**

Chỉ tài liệu có Tag tương ứng được hiển thị.

---

## 14. Ảnh minh chứng

Ảnh được lưu trong:

```text
screenshots/map_tagging/
```

Danh sách ảnh đề xuất:

```text
01_tag_input_enter.png
02_tag_input_comma.png
03_tag_suggestions.png
04_location_picker_map.png
05_current_location.png
06_location_selected.png
07_document_map_markers.png
08_marker_summary_card.png
09_marker_view_detail.png
10_filter_flutter.png
11_filter_giao_trinh.png
12_add_edit_tag_integration.png
13_search_tag_filter.png
```

---

## 15. Tích hợp với `DocumentModel`

Khi `DocumentModel` chính đã có đủ Data Contract, cần bổ sung:

```dart
final double? latitude;
final double? longitude;
final String? locationName;
final bool isPhysical;
final List<String> tags;
```

Phương thức chuyển từ `DocumentModel` sang `MapDocumentItem` có thể viết:

```dart
MapDocumentItem toMapDocumentItem(
  DocumentModel document,
  SubjectModel? subject,
) {
  return MapDocumentItem(
    id: document.id,
    title: document.title,
    subjectName:
        subject?.name ?? 'Chưa xác định môn học',
    locationName:
        document.locationName ?? 'Chưa có mô tả vị trí',
    latitude: document.latitude!,
    longitude: document.longitude!,
    tags: document.tags,
    isBorrowed:
        document.status != DocumentStatus.pending,
  );
}
```

Chỉ chuyển các tài liệu có đủ tọa độ:

```dart
document.latitude != null &&
document.longitude != null
```

---

## 16. Điểm tích hợp với ứng dụng chính

Nhóm trưởng cần thực hiện khi merge:

1. Giữ các thư mục:

```text
lib/widgets/tags/
lib/widgets/map/
lib/models/map_document_item.dart
```

2. Giữ trang:

```text
lib/pages/document_map_page.dart
```

3. Thay `mockDocumentsWithLocation` bằng danh sách thật từ `DocumentService`.

4. Thêm route hoặc nút mở `DocumentMapPage`.

5. Thay hành động Mock của nút `Xem chi tiết` bằng:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (BuildContext context) {
      return DocumentDetailPage(
        documentId: document.id,
      );
    },
  ),
);
```

6. Lưu các trường sau vào SQLite và Supabase:

```text
latitude
longitude
location_name
is_physical
tags
```

7. Đồng bộ dữ liệu vị trí qua SyncEngine.

---

## 17. Giới hạn hiện tại

- Dữ liệu bản đồ đang sử dụng Mock Data.
- Nút `Xem chi tiết` trong Demo mới hiển thị thông báo.
- Việc lưu tọa độ thật phụ thuộc vào `DocumentModel` và schema do nhóm trưởng hoàn thiện.
- OpenStreetMap cần kết nối Internet để tải Tile.
- Vị trí hiện tại phụ thuộc quyền trình duyệt hoặc quyền Android.
- Độ chính xác vị trí phụ thuộc thiết bị, GPS, Wi-Fi và môi trường kiểm thử.
- Không triển khai bản đồ ngoại tuyến.
- Không tải trước hàng loạt Tile OpenStreetMap.

---

## 18. Tiêu chí hoàn thành

### Tagging

- [x] Nhập Tag bằng Enter.
- [x] Nhập nhiều Tag bằng dấu phẩy.
- [x] Tự thêm ký tự `#`.
- [x] Không tạo Tag trùng.
- [x] Xóa từng Tag.
- [x] Hiển thị Tag gợi ý.
- [x] Tích hợp Tag vào trang thêm/sửa.
- [x] Tích hợp lọc Tag vào trang tìm kiếm.

### Map

- [x] Hiển thị OpenStreetMap.
- [x] Hiển thị Marker.
- [x] Bấm Marker hiện Card.
- [x] Hiển thị tiêu đề, môn học và vị trí.
- [x] Hiển thị Tag và tình trạng mượn.
- [x] Có nút `Xem chi tiết`.
- [x] Lọc Marker theo Tag.
- [x] Bấm bản đồ để chọn tọa độ.
- [x] Lấy vị trí hiện tại.
- [x] Nhập tên vị trí.
- [x] Xác nhận hoặc hủy vị trí.

### Kiểm thử và bàn giao

- [ ] Chạy thử thành công trên Chrome.
- [ ] Chạy thử thành công trên Android.
- [ ] `flutter analyze` đạt 0 error ở code Map & Tagging.
- [ ] Chụp đủ ảnh minh chứng.
- [x] Có Mock Data độc lập.
- [x] Có tài liệu hướng dẫn tích hợp.

> Cập nhật các mục `[ ]` thành `[x]` sau khi đã kiểm thử thực tế.

---

## 19. Kết quả nghiệm thu

### Kết quả kiểm thử Web

```text
Trạng thái: Chưa cập nhật
Thiết bị: Google Chrome
Ghi chú:
```

### Kết quả kiểm thử Android

```text
Trạng thái: Chưa cập nhật
Thiết bị:
Phiên bản Android:
Ghi chú:
```

### Kết quả `flutter analyze`

```text
Số error trong code Map & Tagging:
Số warning:
Số info từ source chung:
```

### Kết luận

Phần Map & Tagging đã được thiết kế theo nguyên tắc Contract-First và Mock Service, có khả năng chạy thử độc lập và hạn chế xung đột với các phần việc khác.

Các thành phần Tag Input, Tag Filter, Location Picker, Current Location, Document Map và Marker Summary Card đã được tách thành các widget riêng. Khi tích hợp, nhóm trưởng chỉ cần thay Mock Data bằng dữ liệu thật và kết nối các callback với `DocumentService`, `DocumentDetailPage`, SQLite cùng Supabase.