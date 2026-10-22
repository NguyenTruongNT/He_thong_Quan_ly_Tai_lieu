import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/widgets/framework/responsive_layout.dart';

void main() {
  group('Kiểm thử Giao diện Thích ứng Đa nền tảng (ResponsiveLayout - Checklist 02)', () {
    testWidgets('1. ResponsiveLayout hiển thị mobileBody khi màn hình < 600px', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobileBody: Text('Mobile View'),
            tabletBody: Text('Tablet View'),
            desktopBody: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Mobile View'), findsOneWidget);
      expect(find.text('Tablet View'), findsNothing);
      expect(find.text('Desktop View'), findsNothing);
    });

    testWidgets('2. ResponsiveLayout hiển thị tabletBody khi 600px <= màn hình <= 1024px', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobileBody: Text('Mobile View'),
            tabletBody: Text('Tablet View'),
            desktopBody: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Mobile View'), findsNothing);
      expect(find.text('Tablet View'), findsOneWidget);
      expect(find.text('Desktop View'), findsNothing);
    });

    testWidgets('3. ResponsiveLayout hiển thị desktopBody khi màn hình > 1024px', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobileBody: Text('Mobile View'),
            tabletBody: Text('Tablet View'),
            desktopBody: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Mobile View'), findsNothing);
      expect(find.text('Tablet View'), findsNothing);
      expect(find.text('Desktop View'), findsOneWidget);
    });

    testWidgets('4. ResponsiveSplitView chỉ hiển thị Master trên màn hình hẹp (< 720px)', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveSplitView(
              master: Text('Master Column'),
              detail: Text('Detail Column'),
            ),
          ),
        ),
      );

      expect(find.text('Master Column'), findsOneWidget);
      expect(find.text('Detail Column'), findsNothing);
    });

    testWidgets('5. ResponsiveSplitView hiển thị cả Master và Detail trên màn hình rộng (>= 720px)', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveSplitView(
              master: Text('Master Column'),
              detail: Text('Detail Column'),
            ),
          ),
        ),
      );

      expect(find.text('Master Column'), findsOneWidget);
      expect(find.text('Detail Column'), findsOneWidget);
    });
  });
}
