import 'package:flutter/material.dart';

import '../mock/mock_documents_with_location.dart';
import '../models/map_document_item.dart';
import '../widgets/map/document_map_widget.dart';

class DocumentMapPage extends StatefulWidget {
  const DocumentMapPage({
    super.key,
    this.documents = mockDocumentsWithLocation,
  });

  final List<MapDocumentItem> documents;

  @override
  State<DocumentMapPage> createState() => _DocumentMapPageState();
}

class _DocumentMapPageState extends State<DocumentMapPage> {
  MapDocumentItem? _selectedDocument;
  String? _selectedTag;

  List<String> get _availableTags {
    final Set<String> tags = <String>{};

    for (final MapDocumentItem document in widget.documents) {
      tags.addAll(document.tags);
    }

    final List<String> sortedTags = tags.toList()..sort();

    return sortedTags;
  }

  List<MapDocumentItem> get _filteredDocuments {
    final String? selectedTag = _selectedTag;

    if (selectedTag == null) {
      return widget.documents;
    }

    return widget.documents.where((MapDocumentItem document) {
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mở chi tiết tài liệu: ${document.title}'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Đóng',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );

    // Khi tích hợp với ứng dụng chính, nhóm trưởng có thể thay
    // SnackBar phía trên bằng điều hướng tới DocumentDetailPage.
    //
    // Ví dụ:
    //
    // Navigator.of(context).push(
    //   MaterialPageRoute<void>(
    //     builder: (BuildContext context) {
    //       return DocumentDetailPage(
    //         documentId: document.id,
    //       );
    //     },
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final List<MapDocumentItem> filteredDocuments = _filteredDocuments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ vị trí tài liệu'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Hiển thị tất cả tài liệu',
            onPressed: () {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: document.markerColor.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.description_rounded,
                    color: document.markerColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        document.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document.subjectName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.place_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(document.locationName)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Icon(Icons.my_location_rounded, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${document.latitude.toStringAsFixed(6)}, '
                    '${document.longitude.toStringAsFixed(6)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: document.tags.map((String tag) {
                return Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(
                  document.isBorrowed
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: document.isBorrowed ? Colors.orange : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    document.isBorrowed
                        ? 'Tài liệu đang được mượn'
                        : 'Tài liệu có sẵn tại vị trí',
                    style: TextStyle(
                      color: document.isBorrowed ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Nút mở chi tiết tài liệu.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onViewDetail,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
