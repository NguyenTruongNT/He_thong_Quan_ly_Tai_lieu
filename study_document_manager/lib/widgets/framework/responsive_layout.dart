import 'package:flutter/material.dart';

// =====================================================================
// [CHECKLIST 02 - GIAO DIỆN ĐA NỀN TẢNG THÍCH ỨNG (RESPONSIVE UI)]
// File: lib/widgets/framework/responsive_layout.dart
// Phụ trách: Thành viên 4 - Lý Đình Sơn
// Mô tả: Cung cấp các Breakpoint chuẩn và các Widget bố cục thích ứng
// tự động co giãn tối ưu cho Mobile (<600px), Tablet (600-1024px) và Desktop/Web (>1024px).
// =====================================================================

/// Bộ điều phối bố cục màn hình thích ứng (Responsive Layout)
class ResponsiveLayout extends StatelessWidget {
  /// Bố cục dành cho màn hình di động (< 600px)
  final Widget mobileBody;

  /// Bố cục dành cho máy tính bảng (600px - 1024px). Nếu null sẽ dùng mobileBody.
  final Widget? tabletBody;

  /// Bố cục dành cho màn hình máy tính / Web rộng (> 1024px). Nếu null sẽ ưu tiên tabletBody rồi đến mobileBody.
  final Widget? desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    this.tabletBody,
    this.desktopBody,
  });

  // --- Các mốc điểm ngắt (Breakpoints) theo quy chuẩn dự án ---
  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;

  /// Kiểm tra có phải màn hình điện thoại (chiều rộng < 600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < mobileBreakpoint;
  }

  /// Kiểm tra có phải màn hình tablet (600px <= chiều rộng <= 1024px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width <= desktopBreakpoint;
  }

  /// Kiểm tra có phải màn hình Desktop/Web rộng (chiều rộng > 1024px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width > desktopBreakpoint;
  }

  /// Kiểm tra xem màn hình có đủ rộng để chia 2 cột không (>= 720px)
  static bool isMasterDetailCapable(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 720.0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > desktopBreakpoint) {
          return desktopBody ?? tabletBody ?? mobileBody;
        } else if (constraints.maxWidth >= mobileBreakpoint) {
          return tabletBody ?? mobileBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}

/// Khung chia 2 cột Master-Detail dành cho Tablet và Desktop
class ResponsiveSplitView extends StatelessWidget {
  /// Khối danh sách (Cột bên trái)
  final Widget master;

  /// Khối chi tiết xem trước (Cột bên phải)
  final Widget detail;

  /// Chiều rộng cố định của cột Master (mặc định 380px)
  final double masterWidth;

  /// Chiều rộng tối thiểu để kích hoạt chia cột (mặc định 720px)
  final double splitBreakpoint;

  const ResponsiveSplitView({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 380.0,
    this.splitBreakpoint = 720.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth < splitBreakpoint) {
      // Khi màn hình nhỏ: chỉ hiển thị cột master
      return master;
    }

    return Row(
      children: [
        SizedBox(
          width: masterWidth,
          child: master,
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Expanded(
          child: detail,
        ),
      ],
    );
  }
}

/// Thanh điều hướng thích ứng: NavigationRail cho Web/Tablet và BottomBar cho Mobile
class ResponsiveNavigationScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  const ResponsiveNavigationScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isTablet(context) || ResponsiveLayout.isDesktop(context);

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: floatingActionButton != null
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: floatingActionButton,
                    )
                  : null,
              destinations: destinations.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon ?? item.icon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon ?? item.icon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

/// Mục điều hướng chuẩn cho thanh Navigation thích ứng
class NavigationDestinationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const NavigationDestinationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}
