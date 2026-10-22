import 'package:flutter/material.dart';

import '../models/map_document_item.dart';

const List<MapDocumentItem> mockDocumentsWithLocation = <MapDocumentItem>[
  MapDocumentItem(
    id: 'doc-01',
    title: 'Giáo trình Lập trình Flutter',
    subjectName: 'Phát triển ứng dụng đa nền tảng',
    locationName: 'Thư viện, khu giáo trình CNTT',
    latitude: 21.00745,
    longitude: 105.82472,
    tags: <String>['#Flutter', '#GiaoTrinh', '#Mobile'],
    markerColor: Colors.blue,
  ),
  MapDocumentItem(
    id: 'doc-02',
    title: 'Bộ đề thi Cơ sở dữ liệu',
    subjectName: 'Cơ sở dữ liệu',
    locationName: 'Giảng đường T35, phòng tự học',
    latitude: 21.00698,
    longitude: 105.82535,
    tags: <String>['#DeThi', '#Database', '#OnTap'],
    markerColor: Colors.orange,
  ),
  MapDocumentItem(
    id: 'doc-03',
    title: 'Slide Firebase Authentication',
    subjectName: 'Phát triển ứng dụng đa nền tảng',
    locationName: 'Phòng thực hành CNTT',
    latitude: 21.00802,
    longitude: 105.82397,
    tags: <String>['#Firebase', '#Slide', '#Flutter'],
    markerColor: Colors.red,
  ),
  MapDocumentItem(
    id: 'doc-04',
    title: 'Tài liệu thực hành Mạng máy tính',
    subjectName: 'Mạng máy tính',
    locationName: 'Phòng thí nghiệm mạng',
    latitude: 21.00712,
    longitude: 105.82342,
    tags: <String>['#ThucHanh', '#Cisco', '#Network'],
    markerColor: Colors.green,
  ),
  MapDocumentItem(
    id: 'doc-05',
    title: 'Giáo trình Trí tuệ nhân tạo',
    subjectName: 'Trí tuệ nhân tạo',
    locationName: 'Kệ sách AI, thư viện',
    latitude: 21.00843,
    longitude: 105.82488,
    tags: <String>['#AI', '#GiaoTrinh', '#Python'],
    isBorrowed: true,
    markerColor: Colors.purple,
  ),
];
