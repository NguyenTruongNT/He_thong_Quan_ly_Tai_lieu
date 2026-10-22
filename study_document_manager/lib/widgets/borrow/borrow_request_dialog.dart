// =====================================================================
// HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP (FLUTTER + FIREBASE + SUPABASE)
// File: lib/widgets/borrow/borrow_request_dialog.dart
// Phụ trách: Checklist 04 (Lending Workflow) - Thành viên: Vũ Hải Đăng
// Mô tả: Hộp thoại xin mượn tài liệu học tập (BorrowRequestDialog):
//   - Chọn ngày hẹn trả linh hoạt (DatePicker & Quick duration chips)
//   - Nhập ghi chú / lý do mượn sách
//   - Tự động nhận diện tài khoản người mượn hiện tại
//   - Hỗ trợ gửi yêu cầu offline và đẩy lên Supabase Cloud
// =====================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../colors.dart';
import '../../database/databaseGlobal.dart';
import '../../functions.dart';
import '../../struct/borrow_service.dart';
import '../../struct/models/borrow_request_model.dart';
import '../../struct/models/document_models.dart';
import '../../struct/supabase_service.dart';

class BorrowRequestDialog extends StatefulWidget {
  final DocumentModel document;
  final VoidCallback? onRequestSent;

  const BorrowRequestDialog({
    super.key,
    required this.document,
    this.onRequestSent,
  });

  static Future<BorrowRequestModel?> show(
    BuildContext context, {
    required DocumentModel document,
    VoidCallback? onRequestSent,
  }) {
    return showDialog<BorrowRequestModel>(
      context: context,
      builder: (ctx) => BorrowRequestDialog(
        document: document,
        onRequestSent: onRequestSent,
      ),
    );
  }

  @override
  State<BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<BorrowRequestDialog> {
  final _noteController = TextEditingController(
    text: 'Em xin mượn tài liệu để phục vụ nghiên cứu và ôn tập thi.',
  );
  late DateTime _selectedDueDate;
  int _selectedDurationDays = 7;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDueDate = DateTime.now().add(Duration(days: _selectedDurationDays));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onQuickDurationSelected(int days) {
    setState(() {
      _selectedDurationDays = days;
      _selectedDueDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'CHỌN NGÀY HẸN TRẢ TÀI LIỆU',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
        );
        _selectedDurationDays = picked.difference(now).inDays + 1;
      });
    }
  }

  Future<void> _submitRequest() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập lời nhắn hoặc lý do mượn.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 1. Xác định thông tin người mượn hiện tại
      final supabaseUser = SupabaseService.instance.currentUser;
      final borrowerId = supabaseUser?.id ?? database.activeOwnerId;
      final borrowerEmail = supabaseUser?.email ??
          (database.activeOwnerId.contains('@')
              ? database.activeOwnerId
              : '${database.activeOwnerId}@tlu.edu.vn');
      final borrowerName = supabaseUser?.userMetadata?['display_name'] ??
          (borrowerEmail.contains('@')
              ? borrowerEmail.split('@').first
              : borrowerEmail);

      // 2. Tạo yêu cầu mượn qua BorrowService
      final request = await BorrowService.instance.createBorrowRequest(
        document: widget.document,
        borrowerId: borrowerId,
        borrowerEmail: borrowerEmail,
        borrowerName: borrowerName?.toString(),
        dueDate: _selectedDueDate,
        note: note,
      );

      if (mounted) {
        openSnackbar(
          context,
          message: 'Đã gửi yêu cầu mượn tài liệu thành công!',
        );
        widget.onRequestSent?.call();
        Navigator.of(context).pop(request);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Không thể gửi yêu cầu: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final doc = widget.document;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: AppColors.bannerGradient,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yêu cầu mượn tài liệu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Gửi yêu cầu tới chủ sở hữu tài liệu',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card thông tin tài liệu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(100),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(doc.type.icon, size: 14, color: doc.type.color),
                                label: Text(doc.type.displayName, style: const TextStyle(fontSize: 11)),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              if (doc.isPhysical) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 12, color: Colors.teal),
                                      SizedBox(width: 4),
                                      Text(
                                        'Sách vật lý',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (doc.locationName != null && doc.locationName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    doc.locationName!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Mục chọn thời gian mượn
                    const Text(
                      'Thời gian mượn dự kiến',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick duration chips
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildDurationChip(3, '3 ngày'),
                        _buildDurationChip(7, '7 ngày (1 tuần)'),
                        _buildDurationChip(14, '14 ngày (2 tuần)'),
                        _buildDurationChip(30, '30 ngày (1 tháng)'),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Ngày hẹn trả cụ thể
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickCustomDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hẹn trả trước ngày',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    dateFormat.format(_selectedDueDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickCustomDate,
                              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                              label: const Text('Đổi ngày', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Ô nhập ghi chú
                    const Text(
                      'Lời nhắn / Lý do mượn *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      maxLength: 250,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Em muốn mượn để tham khảo làm bài tập lớn Tuần 5...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitRequest,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu mượn',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int days, String label) {
    final isSelected = _selectedDurationDays == days;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      onSelected: (val) {
        if (val) _onQuickDurationSelected(days);
      },
    );
  }
}

