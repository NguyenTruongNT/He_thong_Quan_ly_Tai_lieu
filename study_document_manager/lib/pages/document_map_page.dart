import 'package:flutter/material.dart';

import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../mock/mock_documents_with_location.dart';
import '../models/map_document_item.dart';
import '../widgets/map/document_map_widget.dart';
import 'document_detail_page.dart';

class DocumentMapPage extends StatefulWidget {
  const DocumentMapPage({
    super.key,
    this.documents,
  });

  final List<MapDocumentItem>? documents;

  @override
  State<DocumentMapPage> createState() => _DocumentMapPageState();
}

class _DocumentMapPageState extends State<DocumentMapPage> {
  MapDocumentItem? _selectedDocument;
  String? _selectedTag;
  List<MapDocumentItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    if (widget.documents != null) {
      _items = List<MapDocumentItem>.from(widget.documents!);
      return;
    }

    final subjects = {
      for (final s in database.cachedSubjects) s.id: s.name,
    };

    final List<MapDocumentItem> realItems = [];
    for (final doc in database.cachedDocuments) {
      if (doc.latitude != null && doc.longitude != null) {
        realItems.add(
          MapDocumentItem(
            id: doc.id,
            title: doc.title,
            subjectName: subjects[doc.subjectId] ?? 'Tài liệu học tập',
            locationName: doc.locationName ?? 'Vị trí vật lý',
            latitude: doc.latitude!,
            longitude: doc.longitude!,
            tags: doc.tags,
            isBorrowed: false,
            markerColor: doc.isPhysical ? Colors.deepOrange : Colors.blue,
          ),
        );
      }
    }

    // Kết hợp các tài liệu thật và mock data mẫu tại khuôn viên ĐH Thủy Lợi
    final Map<String, MapDocumentItem> merged = {};
    for (final item in mockDocumentsWithLocation) {
      merged[item.id] = item;
    }
    for (final item in realItems) {
      merged[item.id] = item;
    }

    setState(() {
      _items = merged.values.toList();
    });
  }

  List<String> get _availableTags {
    final Set<String> tags = <String>{};

    for (final MapDocumentItem document in _items) {
      tags.addAll(document.tags);
    }

    final List<String> sortedTags = tags.toList()..sort();
    return sortedTags;
  }

  List<MapDocumentItem> get _filteredDocuments {
    final String? selectedTag = _selectedTag;

    if (selectedTag == null) {
      return _items;
    }

    return _items.where((MapDocumentItem document) {
      return document.containsTag(selectedTag);
    }).toList();
  }

  void _selectDocument(MapDocumentItem document) {
    setState(() {
      _selectedDocument = document;
    });
  }

  void _clearSelectedDocument() {
    setState(() {
      _selectedDocument = null;
    });
  }

  void _selectTag(String? tag) {
    setState(() {
      _selectedTag = tag;
      _selectedDocument = null;
    });
  }

  void _openDocumentDetail(MapDocumentItem document) {
    final bool docExists =
        database.cachedDocuments.any((d) => d.id == document.id);

    if (docExists) {
      pushRoute(context, DocumentDetailPage(documentId: document.id));
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  document.title,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Môn học: ${document.subjectName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Vị trí lưu trữ: ${document.locationName}'),
              const SizedBox(height: 4),
              Text('Tọa độ: ${document.latitude.toStringAsFixed(4)}, ${document.longitude.toStringAsFixed(4)}'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: document.tags
                    .map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: document.isBorrowed ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  document.isBorrowed ? 'Trạng thái: Đang được mượn' : 'Trạng thái: Có sẵn để mượn',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: document.isBorrowed ? Colors.red.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MapDocumentItem> filteredDocuments = _filteredDocuments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ vị trí tài liệu'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Làm mới & tải lại tài liệu',
            onPressed: () {
              _loadDocuments();
              _selectTag(null);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DocumentMapWidget(
              documents: filteredDocuments,
              onDocumentSelected: _selectDocument,
            ),
          ),

          // Bộ lọc tài liệu theo tag.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 54,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Tất cả'),
                        selected: _selectedTag == null,
                        onSelected: (_) {
                          _selectTag(null);
                        },
                      ),
                    ),
                    ..._availableTags.map((String tag) {
                      final bool selected = _selectedTag == tag;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (bool value) {
                            _selectTag(value ? tag : null);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Hiển thị số lượng tài liệu sau khi lọc.
          Positioned(
            top: 78,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: Chip(
                avatar: const Icon(Icons.description_outlined, size: 18),
                label: Text('${filteredDocuments.length} tài liệu'),
              ),
            ),
          ),

          // Thông báo khi không có tài liệu phù hợp.
          if (filteredDocuments.isEmpty)
            Positioned(
              top: 140,
              left: 24,
              right: 24,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.location_off_outlined, size: 42),
                      const SizedBox(height: 10),
                      const Text(
                        'Không có tài liệu phù hợp với tag đã chọn.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          _selectTag(null);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Hiển thị tất cả'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Card thông tin khi người dùng bấm vào marker.
          if (_selectedDocument != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _DocumentSummaryCard(
                document: _selectedDocument!,
                onClose: _clearSelectedDocument,
                onViewDetail: () {
                  _openDocumentDetail(_selectedDocument!);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentSummaryCard extends StatelessWidget {
  const _DocumentSummaryCard({
    required this.document,
    required this.onClose,
    required this.onViewDetail,
  });

  final MapDocumentItem document;
  final VoidCallback onClose;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        document.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document.subjectName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    document.locationName,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Icon(Icons.explore_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Tọa độ: ${document.latitude.toStringAsFixed(4)}, ${document.longitude.toStringAsFixed(4)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: document.tags.map((String tag) {
                return Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: document.isBorrowed
                      ? colors.errorContainer
                      : colors.tertiaryContainer,
                  label: Text(
                    document.isBorrowed ? 'Đang mượn' : 'Có sẵn',
                    style: TextStyle(
                      color: document.isBorrowed
                          ? colors.onErrorContainer
                          : colors.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onViewDetail,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Xem chi tiết'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
