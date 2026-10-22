// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/pages/borrow/borrow_management_page.dart
// Phụ trách: Checklist 04 (Lending Workflow) - Thành viên: Vũ Hải Đăng
// Mô tả: Màn hình Quản lý Mượn / Trả tài liệu học tập 2 chiều:
//   - Tab 1: Tài liệu tôi đang mượn (Borrower View)
//   - Tab 2: Yêu cầu mượn gửi tới tôi (Owner View - Duyệt / Từ chối)
//   - Hỗ trợ Reactive Streams cập nhật thời gian thực
//   - Nhận diện trạng thái quá hạn (Overdue Warning)
// =====================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../colors.dart';
import '../../database/databaseGlobal.dart';
import '../../functions.dart';
import '../../struct/borrow_service.dart';
import '../../struct/models/borrow_request_model.dart';
import '../../struct/supabase_service.dart';
import '../../widgets/framework/page_framework.dart';
import '../document_detail_page.dart';

class BorrowManagementPage extends StatefulWidget {
  final int initialTabIndex;

  const BorrowManagementPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<BorrowManagementPage> createState() => _BorrowManagementPageState();
}

class _BorrowManagementPageState extends State<BorrowManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _syncCloudOnStart();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncCloudOnStart() async {
    if (SupabaseService.instance.isInitialized &&
        SupabaseService.instance.currentUser != null) {
      setState(() => _isSyncing = true);
      await BorrowService.instance.syncWithCloud();
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _resolveCurrentUserId() {
    final supabaseUser = SupabaseService.instance.currentUser;
    return supabaseUser?.id ?? database.activeOwnerId;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _resolveCurrentUserId();

    return StreamBuilder<List<BorrowRequestModel>>(
      stream: BorrowService.instance.watchAllBorrowRequests(),
      builder: (context, snapshot) {
        final allRequests = snapshot.data ?? [];

        // Lọc danh sách theo vai trò
        final myBorrowedRequests = allRequests.where((r) {
          return r.borrowerId == currentUserId ||
              (currentUserId.contains('@') && r.borrowerEmail == currentUserId);
        }).toList();

        final incomingRequests = allRequests.where((r) {
          return r.ownerId == currentUserId ||
              (r.ownerId == 'local' && currentUserId == 'local');
        }).toList();

        final pendingIncomingCount =
            incomingRequests.where((r) => r.isPending).length;

        return PageFramework(
          title: 'Quản lý Mượn / Trả tài liệu',
          maxWidth: 1000,
          actions: [
            if (_isSyncing)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: _syncCloudOnStart,
                tooltip: 'Đồng bộ Supabase Cloud',
                icon: const Icon(Icons.sync_rounded),
              ),
          ],
          body: Column(
            children: [
              // Thanh TabBar 2 chiều
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text('Tôi đang mượn'),
                          if (myBorrowedRequests.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _buildCountBadge(
                              myBorrowedRequests.length,
                              backgroundColor: Colors.white.withAlpha(50),
                              textColor: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.move_to_inbox_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text('Yêu cầu tới tôi'),
                          if (pendingIncomingCount > 0) ...[
                            const SizedBox(width: 6),
                            _buildCountBadge(
                              pendingIncomingCount,
                              backgroundColor: Colors.amber.shade700,
                              textColor: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Nội dung của 2 Tab
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Tôi đang mượn (Borrower view)
                    _BorrowerView(
                      requests: myBorrowedRequests,
                      onRefresh: _syncCloudOnStart,
                    ),

                    // Tab 2: Yêu cầu tới tôi (Owner view)
                    _OwnerView(
                      requests: incomingRequests,
                      onRefresh: _syncCloudOnStart,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountBadge(
    int count, {
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// =====================================================================
// TAB 1: DANH SÁCH TÀI LIỆU TÔI ĐANG MƯỢN (BORROWER VIEW)
// =====================================================================
class _BorrowerView extends StatefulWidget {
  final List<BorrowRequestModel> requests;
  final Future<void> Function() onRefresh;

  const _BorrowerView({
    required this.requests,
    required this.onRefresh,
  });

  @override
  State<_BorrowerView> createState() => _BorrowerViewState();
}

class _BorrowerViewState extends State<_BorrowerView> {
  String _filter = 'all'; // 'all' | 'approved' | 'pending' | 'returned'

  @override
  Widget build(BuildContext context) {
    final filtered = widget.requests.where((r) {
      if (_filter == 'all') return true;
      if (_filter == 'overdue') return r.isOverdue;
      return r.status == _filter;
    }).toList();

    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tất cả (${widget.requests.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('approved', 'Đang mượn'),
              const SizedBox(width: 8),
              _buildFilterChip('pending', 'Chờ duyệt'),
              const SizedBox(width: 8),
              _buildFilterChip('overdue', 'Quá hạn ⚠️'),
              const SizedBox(width: 8),
              _buildFilterChip('returned', 'Đã trả'),
            ],
          ),
        ),

        const Divider(height: 12),

        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'Chưa có tài liệu nào đang mượn',
                  subtitle:
                      'Bạn có thể vào xem chi tiết bất kỳ tài liệu nào trên kho tài liệu và bấm nút "Mượn tài liệu".',
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _BorrowRequestCard(
                        request: filtered[index],
                        isBorrowerView: true,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primary.withAlpha(40),
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}

// =====================================================================
// TAB 2: YÊU CẦU MƯỢN GỬI TỚI TÔI (OWNER VIEW)
// =====================================================================
class _OwnerView extends StatefulWidget {
  final List<BorrowRequestModel> requests;
  final Future<void> Function() onRefresh;

  const _OwnerView({
    required this.requests,
    required this.onRefresh,
  });

  @override
  State<_OwnerView> createState() => _OwnerViewState();
}

class _OwnerViewState extends State<_OwnerView> {
  String _filter = 'all'; // 'all' | 'pending' | 'approved' | 'returned'

  @override
  Widget build(BuildContext context) {
    final filtered = widget.requests.where((r) {
      if (_filter == 'all') return true;
      return r.status == _filter;
    }).toList();

    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tất cả (${widget.requests.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('pending', 'Chờ duyệt'),
              const SizedBox(width: 8),
              _buildFilterChip('approved', 'Đang cho mượn'),
              const SizedBox(width: 8),
              _buildFilterChip('returned', 'Đã nhận lại'),
            ],
          ),
        ),

        const Divider(height: 12),

        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Chưa có yêu cầu mượn nào',
                  subtitle:
                      'Khi các bạn sinh viên khác gửi yêu cầu mượn tài liệu của bạn, danh sách duyệt sẽ hiển thị tại đây.',
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _BorrowRequestCard(
                        request: filtered[index],
                        isBorrowerView: false,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primary.withAlpha(40),
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}

// =====================================================================
// THẺ HIỂN THỊ YÊU CẦU MƯỢN (BORROW REQUEST CARD)
// =====================================================================
class _BorrowRequestCard extends StatefulWidget {
  final BorrowRequestModel request;
  final bool isBorrowerView;

  const _BorrowRequestCard({
    required this.request,
    required this.isBorrowerView,
  });

  @override
  State<_BorrowRequestCard> createState() => _BorrowRequestCardState();
}

class _BorrowRequestCardState extends State<_BorrowRequestCard> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      await BorrowService.instance.approveRequest(widget.request);
      if (mounted) {
        openSnackbar(context, message: 'Đã phê duyệt cho mượn tài liệu!');
      }
    } catch (e) {
      if (mounted) {
        openSnackbar(context, message: 'Lỗi phê duyệt: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối yêu cầu mượn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn từ chối yêu cầu mượn này không?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối (không bắt buộc)',
                hintText: 'Ví dụ: Sách đang có người khác mượn...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      setState(() => _isProcessing = true);
      try {
        await BorrowService.instance.rejectRequest(widget.request, reasonController.text);
        if (mounted) {
          openSnackbar(context, message: 'Đã từ chối yêu cầu mượn.');
        }
      } catch (e) {
        if (mounted) {
          openSnackbar(context, message: 'Lỗi: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markReturned() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isBorrowerView ? 'Báo đã trả tài liệu' : 'Xác nhận đã nhận lại sách'),
        content: Text(
          widget.isBorrowerView
              ? 'Xác nhận bạn đã hoàn trả tài liệu này cho chủ sở hữu?'
              : 'Xác nhận người mượn đã hoàn trả tài liệu đầy đủ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Chưa')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await BorrowService.instance.markAsReturned(widget.request);
        if (mounted) {
          openSnackbar(context, message: 'Đã ghi nhận hoàn trả tài liệu thành công!');
        }
      } catch (e) {
        if (mounted) {
          openSnackbar(context, message: 'Lỗi: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy yêu cầu mượn'),
        content: const Text('Bạn có muốn hủy yêu cầu mượn tài liệu này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await BorrowService.instance.deleteRequest(widget.request.id);
        if (mounted) {
          openSnackbar(context, message: 'Đã hủy yêu cầu mượn.');
        }
      } catch (e) {
        if (mounted) {
          openSnackbar(context, message: 'Lỗi: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isOverdue = r.isOverdue;
    final statusColor = isOverdue ? AppColors.error : r.borrowStatus.color;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? AppColors.error.withAlpha(150)
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Tiêu đề tài liệu + Trạng thái
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      pushRoute(context, DocumentDetailPage(documentId: r.documentId));
                    },
                    child: Text(
                      r.documentTitle ?? 'Tài liệu ID: ${r.documentId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverdue ? Icons.warning_amber_rounded : r.borrowStatus.icon,
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOverdue ? 'Quá hạn trả' : r.borrowStatus.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Đối tượng liên quan (Chủ sở hữu hoặc Người mượn)
            Row(
              children: [
                Icon(
                  widget.isBorrowerView ? Icons.account_circle_outlined : Icons.person_pin_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isBorrowerView
                      ? 'Chủ sở hữu: ${r.ownerEmail ?? r.ownerId}'
                      : 'Người mượn: ${r.borrowerName != null ? '${r.borrowerName} (${r.borrowerEmail})' : r.borrowerEmail}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Row 3: Thời gian gửi & Thời gian hẹn trả
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Yêu cầu: ${dateFormat.format(r.requestDate)}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                if (r.dueDate != null) ...[
                  const SizedBox(width: 14),
                  Icon(
                    Icons.alarm_rounded,
                    size: 15,
                    color: isOverdue ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hạn trả: ${dateFormat.format(r.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),

            // Ghi chú mượn
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '“${r.note}”',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],

            // Cảnh báo quá hạn
            if (isOverdue) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã quá thời hạn hẹn trả sách! Vui lòng liên hệ hoàn trả sớm nhất.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Actions Buttons
            if (_isProcessing)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Nút xem tài liệu
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () {
                      pushRoute(context, DocumentDetailPage(documentId: r.documentId));
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Xem tài liệu', style: TextStyle(fontSize: 12)),
                  ),

                  // Hành động dành cho Người mượn (Borrower)
                  if (widget.isBorrowerView) ...[
                    if (r.isPending) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _cancelRequest,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Hủy yêu cầu', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    if (r.isApproved) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _markReturned,
                        icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                        label: const Text('Báo đã trả sách', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],

                  // Hành động dành cho Chủ sở hữu (Owner)
                  if (!widget.isBorrowerView) ...[
                    if (r.isPending) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _reject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Từ chối', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _approve,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Cho mượn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (r.isApproved) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _markReturned,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Đã nhận lại sách', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildEmptyState({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
