import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/models/document_models.dart';
import '../struct/recommendation_service.dart';
import '../widgets/framework/page_framework.dart';

class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final User user;
  final Future<void> Function() onSignOut;

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  bool _isSigningOut = false;
  bool _loadingInterests = true;
  bool _savingInterests = false;

  final Set<String> _selectedSubjectIds = {};
  final Set<String> _selectedTags = {};
  final TextEditingController _newTagController = TextEditingController();

  List<SubjectModel> _allSubjects = [];
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadInterests() async {
    try {
      final subjects = await database.getAllSubjects();
      final docs = await database.getAllDocuments();
      final userInterests = await RecommendationService.getUserInterests(widget.user.uid);
      final docTags = RecommendationService.extractAllTags(docs);

      final commonTags = [
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

      final mergedTags = <String>{...commonTags, ...docTags, ...userInterests.favoriteTags};

      if (mounted) {
        setState(() {
          _allSubjects = subjects;
          _selectedSubjectIds.addAll(userInterests.favoriteSubjectIds);
          _selectedTags.addAll(userInterests.favoriteTags);
          _availableTags = mergedTags.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _loadingInterests = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải sở thích hồ sơ: $e');
      if (mounted) {
        setState(() => _loadingInterests = false);
      }
    }
  }

  void _addCustomTag() {
    final text = _newTagController.text.trim();
    if (text.isEmpty) return;
    final formatted = text.startsWith('#') ? text : '#$text';
    setState(() {
      _selectedTags.add(formatted);
      if (!_availableTags.contains(formatted)) {
        _availableTags.insert(0, formatted);
      }
      _newTagController.clear();
    });
  }

  Future<void> _saveInterests() async {
    setState(() => _savingInterests = true);
    try {
      final newInterests = UserInterests(
        favoriteTags: _selectedTags.toList(),
        favoriteSubjectIds: _selectedSubjectIds.toList(),
      );
      await RecommendationService.saveUserInterests(widget.user.uid, newInterests);
      if (mounted) {
        openSnackbar(context, message: 'Đã cập nhật sở thích học tập!');
      }
    } catch (e) {
      if (mounted) {
        openSnackbar(context, message: 'Lỗi lưu sở thích: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _savingInterests = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Chưa thiết lập tên hiển thị';
    final providerNames = user.providerData
        .map((provider) => provider.providerId)
        .toSet()
        .join(', ');

    return PageFramework(
      title: 'Trang cá nhân',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: user.photoURL?.isNotEmpty != true
                        ? null
                        : NetworkImage(user.photoURL!),
                    child: user.photoURL?.isNotEmpty != true
                        ? const Icon(Icons.person_rounded, size: 44)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user.email?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(user.email!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sở thích học tập (Checklist 05 - Recommendation Engine)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sở thích học tập & Gợi ý AI',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Hệ thống AI sẽ tự động gợi ý các tài liệu phù hợp nhất.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (_loadingInterests)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    // 1. Môn học quan tâm
                    Text(
                      '1. Môn học quan tâm (+1.5 điểm):',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_allSubjects.isEmpty)
                      const Text('Chưa có môn học nào trong hệ thống.', style: TextStyle(fontSize: 12))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _allSubjects.map((s) {
                          final isSelected = _selectedSubjectIds.contains(s.id);
                          return FilterChip(
                            label: Text('[${s.code}] ${s.name}'),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedSubjectIds.add(s.id);
                                } else {
                                  _selectedSubjectIds.remove(s.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 18),

                    // 2. Thẻ Tag quan tâm
                    Text(
                      '2. Thẻ Tag quan tâm (+2.0 điểm/tag):',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTagController,
                            decoration: InputDecoration(
                              hintText: 'Nhập tag mới (vd: #Flutter, #MachineLearning)',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onSubmitted: (_) => _addCustomTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _addCustomTag,
                          tooltip: 'Thêm tag',
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

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        icon: _savingInterests
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Lưu sở thích'),
                        onPressed: _savingInterests ? null : _saveInterests,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Thông tin cá nhân chi tiết
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin cá nhân',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProfileInfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Tên hiển thị',
                    value: displayName,
                  ),
                  _ProfileInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email ?? 'Chưa cung cấp',
                  ),
                  _ProfileInfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Email xác thực',
                    value: user.emailVerified ? 'Đã xác thực' : 'Chưa xác thực',
                  ),
                  _ProfileInfoRow(
                    icon: Icons.login_rounded,
                    label: 'Phương thức đăng nhập',
                    value: providerNames.isEmpty ? 'Google' : providerNames,
                  ),
                  _ProfileInfoRow(
                    icon: Icons.fingerprint_rounded,
                    label: 'Mã tài khoản',
                    value: user.uid,
                  ),
                  if (user.metadata.creationTime != null)
                    _ProfileInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Ngày tạo tài khoản',
                      value: _formatDate(user.metadata.creationTime!),
                    ),
                  if (user.metadata.lastSignInTime != null)
                    _ProfileInfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Đăng nhập gần nhất',
                      value: _formatDate(user.metadata.lastSignInTime!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Thống kê tài liệu
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài liệu của bạn',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<DocumentModel>>(
                    future: database.getAllDocuments(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Không thể tải thống kê: ${snapshot.error}');
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final documents = snapshot.data!;
                      final personal = documents.where((doc) => !doc.isShared);
                      final shared = documents.where((doc) => doc.isShared);
                      return Column(
                        children: [
                          _ProfileInfoRow(
                            icon: Icons.lock_outline_rounded,
                            label: 'Tài liệu riêng',
                            value: '${personal.length}',
                          ),
                          _ProfileInfoRow(
                            icon: Icons.people_outline_rounded,
                            label: 'Tài liệu dùng chung',
                            value: '${shared.length}',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tài liệu riêng chỉ hiển thị trong phạm vi tài khoản này. '
                    'Tài liệu dùng chung có thể được mọi tài khoản xem. '
                    'SQLite hiện lưu dữ liệu trên thiết bị này, chưa đồng bộ '
                    'giữa các thiết bị.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
          if (_isSigningOut) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
