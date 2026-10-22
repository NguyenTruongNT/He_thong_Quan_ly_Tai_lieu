import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/formatters.dart';
import '../struct/models/document_models.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/framework/page_framework.dart';
import '../widgets/tags/tag_input_field.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN: THÊM VÀ SỬA TÀI LIỆU]
// File: lib/pages/add_edit_document_page.dart
//
// Chức năng:
// - Thêm mới hoặc chỉnh sửa tài liệu.
// - Chọn hoặc tạo môn học.
// - Chọn loại tài liệu và thời hạn.
// - Nhập Tag dưới dạng InputChip.
// - Chọn mức độ ưu tiên.
// - Đánh dấu tài liệu quan trọng.
// =====================================================================

class AddEditDocumentPage extends StatefulWidget {
  const AddEditDocumentPage({
    super.key,
    this.initialDocument,
    this.defaultSubjectId,
  });

  final DocumentModel? initialDocument;
  final String? defaultSubjectId;

  @override
  State<AddEditDocumentPage> createState() => _AddEditDocumentPageState();
}

class _AddEditDocumentPageState extends State<AddEditDocumentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _fileUrlController;

  String _subjectInput = '';

  late DocumentType _selectedType;
  late PriorityLevel _selectedPriority;
  late bool _isFavorite;

  String? _selectedSubjectId;
  DateTime? _selectedDeadline;

  List<String> _selectedTags = <String>[];
  List<SubjectModel> _availableSubjects = <SubjectModel>[];

  bool _isLoadingSubjects = true;
  bool _isSaving = false;

  bool get isEditing => widget.initialDocument != null;

  @override
  void initState() {
    super.initState();

    final DocumentModel? document = widget.initialDocument;

    _titleController = TextEditingController(text: document?.title ?? '');

    _notesController = TextEditingController(text: document?.notes ?? '');

    _fileUrlController = TextEditingController(text: document?.fileUrl ?? '');

    _selectedTags = List<String>.from(document?.tags ?? <String>[]);

    _selectedType = document?.type ?? DocumentType.lecture;

    _selectedPriority = document?.priority ?? PriorityLevel.medium;

    _isFavorite = document?.isFavorite ?? false;

    _selectedSubjectId = document?.subjectId ?? widget.defaultSubjectId;

    _selectedDeadline = document?.deadline;

    _loadSubjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _fileUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final List<SubjectModel> subjects = await database.getAllSubjects();

      if (!mounted) {
        return;
      }

      final Iterable<SubjectModel> selectedSubjects = subjects.where(
        (SubjectModel subject) => subject.id == _selectedSubjectId,
      );

      setState(() {
        _availableSubjects = subjects;

        if (selectedSubjects.isNotEmpty) {
          final SubjectModel selectedSubject = selectedSubjects.first;

          _subjectInput =
              '${selectedSubject.code} - '
              '${selectedSubject.name}';
        }

        _isLoadingSubjects = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSubjects = false;
      });

      openSnackbar(
        context,
        message: 'Không thể tải danh sách môn học: $error',
        isError: true,
      );
    }
  }

  (String, String)? _parseSubjectInput(String value) {
    final String input = value.trim();

    final RegExpMatch? separator = RegExp(r'\s+[-–—]\s+').firstMatch(input);

    if (separator == null) {
      return null;
    }

    final String code = input.substring(0, separator.start).trim();

    final String name = input.substring(separator.end).trim();

    if (code.isEmpty || name.isEmpty) {
      return null;
    }

    return (code, name);
  }

  Future<String?> _resolveSubjectId() async {
    final Iterable<SubjectModel> selectedSubjects = _availableSubjects.where(
      (SubjectModel subject) => subject.id == _selectedSubjectId,
    );

    if (selectedSubjects.isNotEmpty) {
      final SubjectModel selectedSubject = selectedSubjects.first;

      final String expectedValue =
          '${selectedSubject.code} - '
          '${selectedSubject.name}';

      if (_subjectInput.trim() == expectedValue) {
        return selectedSubject.id;
      }
    }

    final (String, String)? parsed = _parseSubjectInput(_subjectInput);

    if (parsed == null) {
      openSnackbar(
        context,
        message:
            'Nhập môn theo định dạng MÃ - Tên môn, '
            'hoặc chọn một gợi ý.',
        isError: true,
      );

      return null;
    }

    final String code = parsed.$1;
    final String name = parsed.$2;

    final Iterable<SubjectModel> duplicateCodes = _availableSubjects.where(
      (SubjectModel subject) =>
          subject.code.toLowerCase() == code.toLowerCase(),
    );

    final Iterable<SubjectModel> duplicateNames = _availableSubjects.where(
      (SubjectModel subject) =>
          subject.name.toLowerCase() == name.toLowerCase(),
    );

    if (duplicateCodes.isNotEmpty || duplicateNames.isNotEmpty) {
      final SubjectModel existingSubject = duplicateCodes.isNotEmpty
          ? duplicateCodes.first
          : duplicateNames.first;

      final bool exactMatch =
          existingSubject.code.toLowerCase() == code.toLowerCase() &&
          existingSubject.name.toLowerCase() == name.toLowerCase();

      if (exactMatch) {
        return existingSubject.id;
      }

      openSnackbar(
        context,
        message:
            'Mã hoặc tên môn học đã được dùng '
            'cho một môn khác.',
        isError: true,
      );

      return null;
    }

    final SubjectModel newSubject = SubjectModel(
      id: const Uuid().v4(),
      name: name,
      code: code,
      colorValue: AppColors.primary.toARGB32(),
      iconName: 'school',
      createdDate: DateTime.now(),
    );

    await database.insertSubject(newSubject);

    if (mounted) {
      setState(() {
        _availableSubjects = <SubjectModel>[..._availableSubjects, newSubject];

        _selectedSubjectId = newSubject.id;

        _subjectInput = '${newSubject.code} - ${newSubject.name}';
      });
    }

    return newSubject.id;
  }

  Future<void> _pickDeadline() async {
    final DateTime now = DateTime.now();

    final DateTime initialDate =
        _selectedDeadline ?? now.add(const Duration(days: 3));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDeadline != null
          ? TimeOfDay.fromDateTime(_selectedDeadline!)
          : const TimeOfDay(hour: 23, minute: 59),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDeadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 23,
        pickedTime?.minute ?? 59,
      );
    });
  }

  List<String> _normalizeTags() {
    final Map<String, String> uniqueTags = <String, String>{};

    for (final String rawTag in _selectedTags) {
      final String trimmedTag = rawTag.trim();

      if (trimmedTag.isEmpty) {
        continue;
      }

      final String withoutHash = trimmedTag.startsWith('#')
          ? trimmedTag.substring(1)
          : trimmedTag;

      final String normalizedBody = withoutHash
          .replaceAll(RegExp(r'\s+'), '')
          .trim();

      if (normalizedBody.isEmpty) {
        continue;
      }

      final String normalizedTag = '#$normalizedBody';

      uniqueTags.putIfAbsent(normalizedTag.toLowerCase(), () => normalizedTag);
    }

    return uniqueTags.values.toList();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final FormState? formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String? subjectId = await _resolveSubjectId();

      if (subjectId == null) {
        return;
      }

      final List<String> normalizedTags = _normalizeTags();

      if (isEditing) {
        final DocumentModel updatedDocument = widget.initialDocument!.copyWith(
          title: _titleController.text.trim(),
          subjectId: subjectId,
          type: _selectedType,
          notes: _notesController.text.trim(),
          fileUrl: _fileUrlController.text.trim(),
          tags: normalizedTags,
          priority: _selectedPriority,
          isFavorite: _isFavorite,
          deadline: _selectedDeadline,
        );

        await DocumentService.updateDocument(updatedDocument);

        if (!mounted) {
          return;
        }

        openSnackbar(context, message: 'Đã cập nhật tài liệu thành công!');

        Navigator.pop(context, true);
      } else {
        final DateTime now = DateTime.now();

        final DocumentModel newDocument = DocumentModel(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          subjectId: subjectId,
          type: _selectedType,
          notes: _notesController.text.trim(),
          fileUrl: _fileUrlController.text.trim(),
          tags: normalizedTags,
          status: DocumentStatus.pending,
          priority: _selectedPriority,
          isFavorite: _isFavorite,
          deadline: _selectedDeadline,
          createdDate: now,
          updatedDate: now,
        );

        await DocumentService.saveDocument(newDocument);

        if (!mounted) {
          return;
        }

        openSnackbar(context, message: 'Đã thêm tài liệu học tập mới!');

        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      openSnackbar(context, message: 'Lỗi: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return PageFramework(
      title: isEditing ? 'Chỉnh sửa tài liệu' : 'Thêm tài liệu mới',
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _isSaving
                  ? 'Đang lưu...'
                  : isEditing
                  ? 'Lưu'
                  : 'Tạo mới',
            ),
          ),
        ),
      ],
      body: _isLoadingSubjects
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    'Môn học / Học phần *',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),

                  Autocomplete<SubjectModel>(
                    displayStringForOption: (SubjectModel subject) {
                      return '${subject.code} - '
                          '${subject.name}';
                    },
                    initialValue: TextEditingValue(text: _subjectInput),
                    optionsBuilder: (TextEditingValue value) {
                      final String query = value.text.trim().toLowerCase();

                      if (query.isEmpty) {
                        return const Iterable<SubjectModel>.empty();
                      }

                      return _availableSubjects.where((SubjectModel subject) {
                        return subject.code.toLowerCase().contains(query) ||
                            subject.name.toLowerCase().contains(query);
                      });
                    },
                    onSelected: (SubjectModel subject) {
                      _subjectInput =
                          '${subject.code} - '
                          '${subject.name}';

                      setState(() {
                        _selectedSubjectId = subject.id;
                      });
                    },
                    fieldViewBuilder:
                        (
                          BuildContext context,
                          TextEditingController controller,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            textInputAction: TextInputAction.next,
                            onChanged: (String value) {
                              _subjectInput = value;

                              final Iterable<SubjectModel> selectedSubjects =
                                  _availableSubjects.where((
                                    SubjectModel subject,
                                  ) {
                                    return subject.id == _selectedSubjectId &&
                                        value.trim() ==
                                            '${subject.code} - '
                                                '${subject.name}';
                                  });

                              if (selectedSubjects.isEmpty) {
                                _selectedSubjectId = null;
                              }
                            },
                            onFieldSubmitted: (_) {
                              onFieldSubmitted();
                            },
                            validator: (String? value) {
                              final Iterable<SubjectModel> selectedSubjects =
                                  _availableSubjects.where((
                                    SubjectModel subject,
                                  ) {
                                    return subject.id == _selectedSubjectId &&
                                        value?.trim() ==
                                            '${subject.code} - '
                                                '${subject.name}';
                                  });

                              if (selectedSubjects.isNotEmpty ||
                                  _parseSubjectInput(value ?? '') != null) {
                                return null;
                              }

                              return 'Nhập theo định dạng '
                                  'MÃ - Tên môn.';
                            },
                            decoration: const InputDecoration(
                              hintText:
                                  'Ví dụ: SWE302 - '
                                  'Kiến trúc phần mềm',
                              prefixIcon: Icon(Icons.school_outlined),
                              suffixIcon: Icon(Icons.expand_more_rounded),
                            ),
                          );
                        },
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6, bottom: 12),
                    child: Text(
                      'Chọn gợi ý có sẵn hoặc nhập '
                      'MÃ - Tên môn để tạo môn mới.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),

                  const Text(
                    'Phân loại tài liệu *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DocumentType.values.map((DocumentType type) {
                      final bool selected = _selectedType == type;

                      return ChoiceChip(
                        label: Text(type.displayName),
                        selected: selected,
                        avatar: Icon(
                          type.icon,
                          size: 16,
                          color: selected
                              ? type.color
                              : colors.onSurfaceVariant,
                        ),
                        selectedColor: type.color.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selected ? type.color : null,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selected ? type.color : colors.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (bool value) {
                          if (!value) {
                            return;
                          }

                          setState(() {
                            _selectedType = type;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _titleController,
                    label: 'Tiêu đề tài liệu *',
                    hint:
                        'Ví dụ: Bài tập lớn Kiến trúc '
                        'Phần mềm Tuần 4',
                    prefixIcon: Icons.title_rounded,
                    validator: DocumentService.validateTitle,
                  ),

                  CustomTextField(
                    controller: _fileUrlController,
                    label:
                        'Đường dẫn File / '
                        'Liên kết học tập',
                    hint:
                        'Ví dụ: https://drive.google.com/... '
                        'hoặc tài liệu.pdf',
                    prefixIcon: Icons.link_rounded,
                    validator: DocumentService.validateUrl,
                  ),

                  if (_selectedType == DocumentType.assignment ||
                      _selectedType == DocumentType.exam) ...<Widget>[
                    const Text(
                      'Thời hạn hoàn thành '
                      '(Deadline)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),

                    InkWell(
                      onTap: _pickDeadline,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.event_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDeadline != null
                                    ? DocumentFormatters.formatDateTime(
                                        _selectedDeadline,
                                      )
                                    : 'Chưa đặt hạn nộp '
                                          '(Bấm để chọn)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedDeadline != null
                                      ? colors.onSurface
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_selectedDeadline != null)
                              IconButton(
                                tooltip: 'Xóa thời hạn',
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _selectedDeadline = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  // Tag Input dạng Chip.
                  TagInputField(
                    key: ValueKey<String>(
                      'tag-input-'
                      '${widget.initialDocument?.id ?? 'new'}',
                    ),
                    initialTags: _selectedTags,
                    suggestions: const <String>[
                      '#GiaoTrinh',
                      '#DeThi',
                      '#Slide',
                      '#ThucHanh',
                      '#Flutter',
                      '#Firebase',
                      '#AI',
                      '#Mobile',
                    ],
                    maxTags: 10,
                    onChanged: (List<String> tags) {
                      _selectedTags = List<String>.from(tags);
                    },
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Mức độ ưu tiên',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  SegmentedButton<PriorityLevel>(
                    segments: const <ButtonSegment<PriorityLevel>>[
                      ButtonSegment<PriorityLevel>(
                        value: PriorityLevel.low,
                        label: Text('Thấp'),
                      ),
                      ButtonSegment<PriorityLevel>(
                        value: PriorityLevel.medium,
                        label: Text('Bình thường'),
                      ),
                      ButtonSegment<PriorityLevel>(
                        value: PriorityLevel.high,
                        label: Text('Cao / Gấp'),
                      ),
                    ],
                    selected: <PriorityLevel>{_selectedPriority},
                    onSelectionChanged: (Set<PriorityLevel> values) {
                      setState(() {
                        _selectedPriority = values.first;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _notesController,
                    label: 'Ghi chú & Tóm tắt nội dung',
                    hint:
                        'Ghi chú nội dung trọng tâm '
                        'cần ghi nhớ...',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 4,
                  ),

                  SwitchListTile(
                    title: const Text(
                      'Đánh dấu tài liệu quan trọng',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Ghim hoặc gắn sao để xem nhanh '
                      'tại trang chủ',
                    ),
                    value: _isFavorite,
                    activeThumbColor: AppColors.warning,
                    onChanged: (bool value) {
                      setState(() {
                        _isFavorite = value;
                      });
                    },
                    secondary: Icon(
                      _isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: _isFavorite
                          ? AppColors.warning
                          : colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
