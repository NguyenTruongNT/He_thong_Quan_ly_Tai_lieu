import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/formatters.dart';
import '../struct/models/document_models.dart';
import '../struct/models/document_permission.dart';
import '../struct/supabase_service.dart';
import '../widgets/cloud/cloud_sync_badge.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({
    super.key,
    required this.documentId,
    this.isEmbedded = false,
    this.onDocumentDeleted,
  });

  final String documentId;
  final bool isEmbedded;
  final VoidCallback? onDocumentDeleted;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  SubjectModel? _subject;
  Object? _loadError;
  bool _loading = true;
  bool _canEdit = false;
  bool _canManageSharing = false;
  DocumentPermission? _currentPermission;

  @override
  void didUpdateWidget(DocumentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _loading = true;
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final document = await database.getDocumentById(widget.documentId);
      final subject = document == null
          ? null
          : await database.getSubjectById(document.subjectId);
      final canEdit = document == null
          ? false
          : await database.canEditDocument(document.id);
      final canManageSharing = document == null
          ? false
          : await database.canManageSharing(document.id);
      final permission = document == null
          ? null
          : await database.getPermissionForCurrentUser(document.id);
      if (!mounted) return;
      setState(() {
        _document = document;
        _subject = subject;
        _canEdit = canEdit;
        _canManageSharing = canManageSharing;
        _currentPermission = permission;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final document = _document;
    if (document == null || !_canEdit) return;
    await DocumentService.toggleFavorite(document);
    await _load();
  }

  Future<void> _toggleStatus() async {
    final document = _document;
    if (document == null || !_canEdit) return;
    await DocumentService.toggleStatus(document);
    await _load();
  }

  Future<void> _edit() async {
    final document = _document;
    if (document == null || !_canEdit) return;
    final changed = await pushRoute<bool>(
      context,
      AddEditDocumentPage(initialDocument: document),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete() async {
    final document = _document;
    if (document == null || !_canManageSharing) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        documentTitle: document.title,
        onConfirm: () async {
          try {
            await DocumentService.deleteDocument(document.id);
            if (mounted) {
              openSnackbar(context, message: 'Đã xóa tài liệu.');
              if (widget.isEmbedded) {
                widget.onDocumentDeleted?.call();
              } else {
                Navigator.pop(context, true);
              }
            }
          } catch (error) {
            if (mounted) {
              openSnackbar(
                context,
                message: 'Không thể xóa tài liệu: $error',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _manageSharing() async {
    final document = _document;
    if (document == null || !_canManageSharing) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ShareDocumentDialog(
        document: document,
        onChanged: _load,
      ),
    );
  }

  Future<void> _openSource(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) {
        throw FormatException('Đường dẫn không hợp lệ: $value');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Không tìm thấy ứng dụng để mở liên kết.');
    } on PlatformException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể mở tài liệu: ${error.message ?? error.code}',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể mở tài liệu: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _openStorageObject(String storagePath) async {
    try {
      final url = await FirebaseStorageService.instance.downloadUrl(
        storagePath,
      );
      await _openSource(url);
    } catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể tải tệp từ Firebase Storage: $error',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return PageFramework(
        title: 'Chi tiết tài liệu',
        body: Center(child: Text('Không thể tải tài liệu: $_loadError')),
      );
    }
    final document = _document;
    if (document == null) {
      return PageFramework(
        title: 'Không tìm thấy tài liệu',
        body: const Center(
          child: Text('Tài liệu đã bị xóa hoặc không tồn tại.'),
        ),
      );
    }

    final isAssignment = document.type == DocumentType.assignment;
    final isCompleted = document.status == DocumentStatus.completed;
    final sourceLabel = document.storagePath == null
        ? document.fileUrl
        : FirebaseStorageService.fileNameFromPath(document.storagePath!);

    return PageFramework(
      title: 'Chi tiết tài liệu',
      showBackButton: !widget.isEmbedded,
      actions: [
        if (_canManageSharing)
          IconButton(
            onPressed: _manageSharing,
            tooltip: 'Chia sẻ',
            icon: const Icon(Icons.share_outlined),
          ),
        if (_canEdit) ...[
          IconButton(
            onPressed: _toggleFavorite,
            tooltip: 'Yêu thích',
            icon: Icon(
              document.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: document.isFavorite ? AppColors.warning : null,
            ),
          ),
          IconButton(
            onPressed: _edit,
            tooltip: 'Chỉnh sửa',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
        if (_canManageSharing)
          IconButton(
            onPressed: _delete,
            tooltip: 'Xóa',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (document.isShared)
                    const Chip(
                      avatar: Icon(Icons.people_outline_rounded),
                      label: Text('Tài liệu mẫu dùng chung · Chỉ đọc'),
                    ),
                  if (_currentPermission != null)
                    Chip(
                      avatar: const Icon(Icons.people_outline_rounded),
                      label: Text(
                        _currentPermission!.role ==
                                DocumentPermissionRole.editor
                            ? 'Được chia sẻ với quyền chỉnh sửa'
                            : 'Được chia sẻ · Chỉ xem',
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          document.type.icon,
                          color: document.type.color,
                        ),
                        label: Text(document.type.displayName),
                      ),
                      if (_subject != null)
                        Chip(
                          label: Text('${_subject!.code} · ${_subject!.name}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    document.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cập nhật ${DocumentFormatters.formatDateTime(document.updatedDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isAssignment) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle_outline
                            : Icons.pending_actions_outlined,
                        color: document.status.color,
                      ),
                      title: Text('Trạng thái: ${document.status.displayName}'),
                      subtitle: document.deadline == null
                          ? null
                          : Text(
                              'Hạn nộp: ${DocumentFormatters.formatDateTime(document.deadline)}',
                            ),
                      trailing: !_canEdit
                          ? null
                          : IconButton(
                              tooltip: 'Đổi trạng thái',
                              onPressed: _toggleStatus,
                              icon: const Icon(Icons.swap_horiz_rounded),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (document.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ghi chú',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(document.notes),
                  ],
                ),
              ),
            ),
          ],
          if (sourceLabel.isNotEmpty || document.localPath != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: Text(
                  sourceLabel.isEmpty ? 'Tệp lưu cục bộ' : sourceLabel,
                ),
                subtitle: document.storagePath != null
                    ? const CloudSyncBadge(fileUrl: null)
                    : Text(document.localPath ?? document.fileUrl),
                trailing: sourceLabel.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Mở tài liệu',
                        onPressed: document.storagePath != null
                            ? () => _openStorageObject(document.storagePath!)
                            : () => _openSource(document.fileUrl),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
              ),
            ),
          ],
          if (document.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: document.tags
                  .map((tag) => Chip(label: Text('#$tag')))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// DIALOG CHIA SẺ TÀI LIỆU VỚI TÀI KHOẢN GMAIL THỰC TẾ TRÊN CLOUD
// =====================================================================
class _ShareDocumentDialog extends StatefulWidget {
  const _ShareDocumentDialog({
    required this.document,
    required this.onChanged,
  });

  final DocumentModel document;
  final Future<void> Function() onChanged;

  @override
  State<_ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<_ShareDocumentDialog> {
  final _targetController = TextEditingController();
  var _selectedRole = DocumentPermissionRole.viewer;
  var _permissions = <DocumentPermission>[];
  var _cloudProfiles = <Map<String, dynamic>>[];
  bool _isLoadingProfiles = false;
  bool _isSharing = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final localPerms = await database.getDocumentPermissions(widget.document.id);
    if (!mounted) return;
    setState(() => _permissions = localPerms);

    if (SupabaseService.instance.isInitialized) {
      setState(() => _isLoadingProfiles = true);
      try {
        final profiles = await SupabaseService.instance.getAllProfiles();
        final currentEmail = SupabaseService.instance.currentUser?.email?.toLowerCase();
        final currentId = SupabaseService.instance.currentUser?.id;

        // Lọc bỏ tài khoản của chính người dùng hiện tại
        final filtered = profiles.where((p) {
          final pEmail = p['email']?.toString().toLowerCase();
          final pId = p['id']?.toString();
          if (currentEmail != null && pEmail == currentEmail) return false;
          if (currentId != null && pId == currentId) return false;
          return true;
        }).toList();

        if (mounted) {
          setState(() {
            _cloudProfiles = filtered;
            _isLoadingProfiles = false;
          });
        }
      } catch (e) {
        debugPrint('[ShareDialog] Error loading profiles: $e');
        if (mounted) setState(() => _isLoadingProfiles = false);
      }
    }
  }

  Future<void> _handleShare() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Vui lòng chọn hoặc nhập email người nhận.';
      });
      return;
    }

    setState(() {
      _isSharing = true;
      _statusMessage = null;
    });

    try {
      // 1. Lưu quyền vào SQLite máy cục bộ
      await database.shareDocument(
        documentId: widget.document.id,
        targetUserId: target,
        role: _selectedRole,
      );

      // 2. Đồng bộ quyền lên Supabase Cloud nếu đã kết nối
      if (SupabaseService.instance.isInitialized &&
          SupabaseService.instance.currentUser != null) {
        try {
          // Đảm bảo tài liệu đã tồn tại trong bảng documents trên Supabase (thỏa mãn Foreign Key)
          await SupabaseService.instance.ensureDocumentExists(widget.document);

          if (target.contains('@')) {
            await SupabaseService.instance.shareDocumentByEmail(
              documentId: widget.document.id,
              email: target,
              role: _selectedRole,
            );
          } else {
            await SupabaseService.instance.shareDocument(
              documentId: widget.document.id,
              targetUserId: target,
              role: _selectedRole,
            );
          }
        } catch (e) {
          debugPrint('[ShareDialog] Supabase share sync: $e');
        }
      }

      final updated = await database.getDocumentPermissions(widget.document.id);
      _targetController.clear();
      await widget.onChanged();

      if (mounted) {
        setState(() {
          _isSharing = false;
          _permissions = updated;
          _isError = false;
          _statusMessage = 'Đã chia sẻ quyền truy cập thành công cho $target!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _isError = true;
          _statusMessage = 'Lỗi chia sẻ: $e';
        });
      }
    }
  }

  Future<void> _handleRevoke(String targetUserId) async {
    try {
      await database.revokeDocumentShare(
        documentId: widget.document.id,
        targetUserId: targetUserId,
      );

      if (SupabaseService.instance.isInitialized &&
          SupabaseService.instance.currentUser != null) {
        try {
          await SupabaseService.instance.revokeDocumentShare(
            documentId: widget.document.id,
            targetUserId: targetUserId,
          );
        } catch (_) {}
      }

      final updated = await database.getDocumentPermissions(widget.document.id);
      await widget.onChanged();

      if (mounted) {
        setState(() {
          _permissions = updated;
          _isError = false;
          _statusMessage = 'Đã thu hồi quyền của $targetUserId.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _statusMessage = 'Không thể thu hồi quyền: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.share_rounded, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chia sẻ tài liệu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingProfiles)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              // Gợi ý nhanh các tài khoản Gmail thực tế trong Supabase
              if (_cloudProfiles.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.cloud_outlined, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Tài khoản Gmail khả dụng trong hệ thống:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _cloudProfiles.map((profile) {
                    final email = (profile['email'] ?? '').toString();
                    final displayName = (profile['display_name'] ?? '').toString();
                    final label = email.isNotEmpty ? email : displayName;
                    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
                    final isSelected =
                        _targetController.text.trim().toLowerCase() == email.toLowerCase();

                    return FilterChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _targetController.text = selected ? email : '';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Ô nhập tài khoản người nhận
              TextField(
                controller: _targetController,
                decoration: InputDecoration(
                  labelText: 'Email hoặc Mã người nhận',
                  hintText: 'Nhập email Gmail (ví dụ: user@gmail.com)',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Lựa chọn vai trò phân quyền
              Text(
                'Quyền hạn phân phối:',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SegmentedButton<DocumentPermissionRole>(
                segments: const [
                  ButtonSegment(
                    value: DocumentPermissionRole.viewer,
                    label: Text('Chỉ xem'),
                    icon: Icon(Icons.visibility_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: DocumentPermissionRole.editor,
                    label: Text('Chỉnh sửa'),
                    icon: Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (set) => setState(() => _selectedRole = set.first),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isError ? colorScheme.errorContainer : colorScheme.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isError ? Icons.error_outline : Icons.check_circle_outline,
                        size: 16,
                        color: _isError ? colorScheme.error : colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Danh sách những người đang có quyền truy cập
              if (_permissions.isNotEmpty) ...[
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Đang chia sẻ với (${_permissions.length} người)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._permissions.map((p) {
                  final initial = p.sharedWithUserId.isNotEmpty
                      ? p.sharedWithUserId[0].toUpperCase()
                      : '?';
                  final isEditor = p.role == DocumentPermissionRole.editor;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isEditor ? AppColors.accentLight : AppColors.primaryLight,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isEditor ? AppColors.accent : AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        p.sharedWithUserId,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEditor
                                  ? AppColors.accent.withAlpha(30)
                                  : AppColors.success.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEditor ? 'Có thể chỉnh sửa' : 'Chỉ xem',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isEditor ? AppColors.accent : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove_outlined, size: 18),
                        color: colorScheme.error,
                        tooltip: 'Thu hồi quyền',
                        onPressed: () => _handleRevoke(p.sharedWithUserId),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: _isSharing ? null : _handleShare,
          icon: _isSharing
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Chia sẻ'),
        ),
      ],
    );
  }
}
