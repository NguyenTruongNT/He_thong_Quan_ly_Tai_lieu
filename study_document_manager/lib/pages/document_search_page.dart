import 'package:flutter/material.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/models/document_models.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/document_card.dart';
import '../widgets/document_search_bar.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: TÌM KIẾM TÀI LIỆU]
// File: lib/pages/document_search_page.dart
//
// Chức năng:
// - Tìm kiếm theo tiêu đề, ghi chú và Tag.
// - Lọc theo loại tài liệu.
// - Lọc theo môn học.
// - Lọc tài liệu yêu thích.
// - Lọc nhanh bằng Tag Chip.
// - Chỉnh sửa, xóa và cập nhật trạng thái tài liệu.
// =====================================================================

class DocumentSearchPage extends StatefulWidget {
  const DocumentSearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<DocumentSearchPage> createState() => _DocumentSearchPageState();
}

class _DocumentSearchPageState extends State<DocumentSearchPage> {
  static const List<String> _popularTags = <String>[
    '#GiaoTrinh',
    '#DeThi',
    '#Slide',
    '#ThucHanh',
    '#Flutter',
    '#Firebase',
    '#AI',
    '#Mobile',
  ];

  late final TextEditingController _searchController;

  String _query = '';
  String? _selectedTag;
  DocumentType? _typeFilter;
  String? _subjectFilter;
  bool _onlyFavorites = false;

  List<DocumentModel> _results = <DocumentModel>[];

  Map<String, SubjectModel> _subjectMap = <String, SubjectModel>{};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _query = widget.initialQuery ?? '';

    _searchController = TextEditingController(text: _query);

    _searchController.selection = TextSelection.collapsed(
      offset: _query.length,
    );

    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeTag(String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final String withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;

    final String normalized = withoutHash
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();

    return normalized.isEmpty ? '' : '#$normalized';
  }

  bool _documentMatchesTag(DocumentModel document, String? selectedTag) {
    if (selectedTag == null) {
      return true;
    }

    final String normalizedSelectedTag = _normalizeTag(selectedTag);

    return document.tags.any((String documentTag) {
      return _normalizeTag(documentTag) == normalizedSelectedTag;
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final List<SubjectModel> subjects = await database.getAllSubjects();

      if (!mounted) {
        return;
      }

      _subjectMap = <String, SubjectModel>{
        for (final SubjectModel subject in subjects) subject.id: subject,
      };

      await _performSearch();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải dữ liệu tìm kiếm: $error';
      });
    }
  }

  Future<void> _performSearch() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<DocumentModel> documents = await database.searchDocuments(
        query: _query,
        subjectId: _subjectFilter,
        type: _typeFilter,
        onlyFavorite: _onlyFavorites,
      );

      final List<DocumentModel> filteredDocuments = documents.where((
        DocumentModel document,
      ) {
        return _documentMatchesTag(document, _selectedTag);
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _results = filteredDocuments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = <DocumentModel>[];
        _isLoading = false;
        _errorMessage = 'Không thể tìm kiếm tài liệu: $error';
      });
    }
  }

  void _selectTag(String? tag) {
    setState(() {
      _selectedTag = tag;
    });

    _performSearch();
  }

  void _clearAllFilters() {
    _searchController.clear();

    setState(() {
      _query = '';
      _selectedTag = null;
      _typeFilter = null;
      _subjectFilter = null;
      _onlyFavorites = false;
    });

    _performSearch();
  }

  Future<void> _onFavoriteToggle(DocumentModel document) async {
    await DocumentService.toggleFavorite(document);
    await _performSearch();
  }

  Future<void> _onStatusToggle(DocumentModel document) async {
    await DocumentService.toggleStatus(document);
    await _performSearch();
  }

  void _onDelete(DocumentModel document) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return ConfirmDeleteDialog(
          documentTitle: document.title,
          onConfirm: () async {
            await DocumentService.deleteDocument(document.id);

            if (!mounted) {
              return;
            }

            openSnackbar(context, message: 'Đã xóa tài liệu!');

            await _performSearch();
          },
        );
      },
    );
  }

  Future<void> _onEdit(DocumentModel document) async {
    final dynamic result = await pushRoute(
      context,
      AddEditDocumentPage(initialDocument: document),
    );

    if (result == true) {
      await _performSearch();
    }
  }

  Future<void> _openDocumentDetail(DocumentModel document) async {
    final dynamic result = await pushRoute(
      context,
      DocumentDetailPage(documentId: document.id),
    );

    if (result == true) {
      await _performSearch();
    }
  }

  Widget _buildTagFilterBar(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: <Widget>[
              Icon(Icons.tag_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              const Text(
                'Lọc nhanh theo Tag',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedTag != null)
                TextButton(
                  onPressed: () {
                    _selectTag(null);
                  },
                  child: const Text('Bỏ lọc'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: const Icon(Icons.apps_rounded, size: 17),
                  label: const Text('Tất cả'),
                  selected: _selectedTag == null,
                  onSelected: (_) {
                    _selectTag(null);
                  },
                ),
              ),
              ..._popularTags.map((String tag) {
                final bool selected =
                    _normalizeTag(_selectedTag ?? '') == _normalizeTag(tag);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.tag_rounded, size: 17),
                    label: Text(tag),
                    selected: selected,
                    selectedColor: colors.primaryContainer,
                    checkmarkColor: colors.onPrimaryContainer,
                    onSelected: (bool value) {
                      _selectTag(value ? tag : null);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _subjectFilter,
                  hint: const Text(
                    'Tất cả môn học',
                    style: TextStyle(fontSize: 12),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Tất cả môn học',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    ..._subjectMap.values.map((SubjectModel subject) {
                      return DropdownMenuItem<String?>(
                        value: subject.id,
                        child: Text(
                          '[${subject.code}] '
                          '${subject.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _subjectFilter = value;
                    });

                    _performSearch();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Quan trọng', style: TextStyle(fontSize: 12)),
            selected: _onlyFavorites,
            avatar: Icon(
              _onlyFavorites ? Icons.star_rounded : Icons.star_border_rounded,
              size: 16,
              color: _onlyFavorites
                  ? AppColors.warning
                  : colors.onSurfaceVariant,
            ),
            selectedColor: AppColors.warning.withValues(alpha: 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: (bool value) {
              setState(() {
                _onlyFavorites = value;
              });

              _performSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool hasActiveFilter =
        _query.trim().isNotEmpty ||
        _selectedTag != null ||
        _typeFilter != null ||
        _subjectFilter != null ||
        _onlyFavorites;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Tìm thấy ${_results.length} '
              'tài liệu phù hợp',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (hasActiveFilter)
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Xóa bộ lọc'),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                size: 58,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Không tìm thấy tài liệu nào',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _selectedTag == null
                    ? 'Thử thay đổi từ khóa hoặc '
                          'bộ lọc tìm kiếm.'
                    : 'Không có tài liệu mang Tag '
                          '$_selectedTag.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Hiển thị tất cả'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (BuildContext context, int index) {
        final DocumentModel document = _results[index];

        final SubjectModel? subject = _subjectMap[document.subjectId];

        return DocumentCard(
          document: document,
          subject: subject,
          onTap: () {
            _openDocumentDetail(document);
          },
          onFavoriteToggle: () {
            _onFavoriteToggle(document);
          },
          onStatusToggle: () {
            _onStatusToggle(document);
          },
          onEdit: () {
            _onEdit(document);
          },
          onDelete: () {
            _onDelete(document);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: 'Tìm kiếm tài liệu',
      body: Column(
        children: <Widget>[
          DocumentSearchBar(
            controller: _searchController,
            hintText:
                'Nhập tên tài liệu, ghi chú '
                'hoặc thẻ #tag...',
            onChanged: (String value) {
              _query = value;
              _performSearch();
            },
            onClear: () {
              _searchController.clear();
              _query = '';
              _performSearch();
            },
          ),

          FilterChipBar(
            selectedType: _typeFilter,
            onSelected: (DocumentType? type) {
              setState(() {
                _typeFilter = type;
              });

              _performSearch();
            },
          ),

          // Thanh Tag Chip cuộn ngang.
          _buildTagFilterBar(context),

          // Bộ lọc môn học và tài liệu yêu thích.
          _buildAdvancedFilters(context),

          // Hiển thị số lượng kết quả.
          _buildResultHeader(context),

          // Danh sách tài liệu phù hợp.
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }
}
