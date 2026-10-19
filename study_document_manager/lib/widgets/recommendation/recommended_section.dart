import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../functions.dart';
import '../../pages/document_detail_page.dart';
import '../../struct/models/document_models.dart';
import '../../struct/recommendation_service.dart';

// =====================================================================
// [CHECKLIST 05 - GIAO DIỆN HIỂN THỊ GỢI Ý THÔNG MINH]
// File: lib/widgets/recommendation/recommended_section.dart
// Phụ trách: Thành viên 4 - Lý Đình Sơn
// Mô tả: Khối hiển thị danh sách tài liệu gợi ý theo thuật toán Recommendation,
// kèm theo lý do gợi ý (Explainable AI) và công cụ chỉnh sửa sở thích học tập.
// =====================================================================

class RecommendedSection extends StatelessWidget {
  final List<DocumentModel> allDocuments;
  final Map<String, SubjectModel> subjects;
  final String activeUserId;
  final VoidCallback? onSettingsTap;

  const RecommendedSection({
    super.key,
    required this.allDocuments,
    required this.subjects,
    required this.activeUserId,
    this.onSettingsTap,
  });

  void _openPreferencesDialog(BuildContext context) {
    if (onSettingsTap != null) {
      onSettingsTap!();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => UserInterestsDialog(
        userId: activeUserId,
        subjects: subjects.values.toList(),
        allDocuments: allDocuments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserInterests>(
      valueListenable: RecommendationService.interestsNotifier,
      builder: (context, interests, _) {
        final recommendations = RecommendationService.getRecommendations(
          allDocs: allDocuments,
          interests: interests,
          subjectMap: subjects,
          limit: 6,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Gợi ý tài liệu cho bạn',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.amber.shade700.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'AI Match',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          interests.isEmpty
                              ? 'Chưa thiết lập sở thích học tập'
                              : '${interests.favoriteTags.length} thẻ · ${interests.favoriteSubjectIds.length} môn quan tâm',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    tooltip: 'Tùy chỉnh sở thích',
                    onPressed: () => _openPreferencesDialog(context),
                  ),
                ],
              ),
            ),
            if (interests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tips_and_updates_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Chọn các môn học và chủ đề yêu thích để hệ thống gợi ý tài liệu chính xác nhất!',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openPreferencesDialog(context),
                        child: const Text('Thiết lập'),
                      ),
                    ],
                  ),
                ),
              )
            else if (recommendations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_off_rounded,
                          color: Theme.of(context).colorScheme.outline, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chưa tìm thấy tài liệu phù hợp với sở thích hiện tại.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openPreferencesDialog(context),
                        child: const Text('Thêm thẻ khác'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 185,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: recommendations.length,
                  itemBuilder: (context, index) {
                    final item = recommendations[index];
                    final subject = subjects[item.document.subjectId];
                    return _RecommendationCard(
                      result: item,
                      subject: subject,
                      onTap: () => pushRoute(
                        context,
                        DocumentDetailPage(documentId: item.document.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final RecommendationResult result;
  final SubjectModel? subject;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.result,
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = result.document;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: doc.type.color.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng trên: Môn học và Điểm match
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject != null ? '[${subject!.code}]' : 'Tài liệu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: subject?.color ?? doc.type.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 12, color: AppColors.primary),
                          Text(
                            '${result.score.toStringAsFixed(1)}đ',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Tiêu đề tài liệu
                Expanded(
                  child: Text(
                    doc.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 6),

                // Badge lý do gợi ý (Explainable AI)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 13,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          result.reason,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại cho phép người dùng tùy chỉnh sở thích để nhận gợi ý
class UserInterestsDialog extends StatefulWidget {
  final String userId;
  final List<SubjectModel> subjects;
  final List<DocumentModel> allDocuments;

  const UserInterestsDialog({
    super.key,
    required this.userId,
    required this.subjects,
    required this.allDocuments,
  });

  @override
  State<UserInterestsDialog> createState() => _UserInterestsDialogState();
}

class _UserInterestsDialogState extends State<UserInterestsDialog> {
  final Set<String> _selectedSubjectIds = {};
  final Set<String> _selectedTags = {};
  final TextEditingController _customTagController = TextEditingController();
  List<String> _availableTags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final interests = await RecommendationService.getUserInterests(widget.userId);
    final tagsFromDocs = RecommendationService.extractAllTags(widget.allDocuments);

    final defaultCommonTags = [
      '#Flutter',
      '#Mobile',
      '#AI',
      '#Database',
      '#SQL',
      '#ToanRoiRac',
      '#GiaoTrinh',
      '#DeThi',
      '#Slide',
      '#DoAn',
    ];

    final mergedTags = <String>{...defaultCommonTags, ...tagsFromDocs, ...interests.favoriteTags};

    if (mounted) {
      setState(() {
        _selectedSubjectIds.addAll(interests.favoriteSubjectIds);
        _selectedTags.addAll(interests.favoriteTags);
        _availableTags = mergedTags.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _loading = false;
      });
    }
  }

  void _addCustomTag() {
    final text = _customTagController.text.trim();
    if (text.isEmpty) return;
    final formatted = text.startsWith('#') ? text : '#$text';
    setState(() {
      _selectedTags.add(formatted);
      if (!_availableTags.contains(formatted)) {
        _availableTags.insert(0, formatted);
      }
      _customTagController.clear();
    });
  }

  Future<void> _save() async {
    final newInterests = UserInterests(
      favoriteTags: _selectedTags.toList(),
      favoriteSubjectIds: _selectedSubjectIds.toList(),
    );
    await RecommendationService.saveUserInterests(widget.userId, newInterests);
    if (mounted) {
      Navigator.pop(context);
      openSnackbar(context, message: 'Đã lưu sở thích học tập!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sở thích học tập & Gợi ý AI',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      'Hệ thống sẽ gợi ý tài liệu dựa trên môn học và thẻ bạn chọn (+2.0đ/thẻ, +1.5đ/môn).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          Text(
                            '1. Môn học quan tâm:',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (widget.subjects.isEmpty)
                            const Text('Chưa có môn học nào.', style: TextStyle(fontSize: 12))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: widget.subjects.map((sub) {
                                final isSelected = _selectedSubjectIds.contains(sub.id);
                                return FilterChip(
                                  label: Text('[${sub.code}] ${sub.name}'),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedSubjectIds.add(sub.id);
                                      } else {
                                        _selectedSubjectIds.remove(sub.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            '2. Thẻ Tag quan tâm:',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customTagController,
                                  decoration: InputDecoration(
                                    hintText: 'Thêm tag (vd: #Flutter, #AI)',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onSubmitted: (_) => _addCustomTag(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: _addCustomTag,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _availableTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedTags.add(tag);
                                    } else {
                                      _selectedTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Lưu sở thích'),
                          onPressed: _save,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
