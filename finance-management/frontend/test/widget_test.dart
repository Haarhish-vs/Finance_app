import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/currency_formatter.dart';
import 'package:frontend/main.dart';

void main() {
  group('CurrencyFormatter (Indian Rupee - INR / en_IN)', () {
    test('formats Indian number grouping correctly', () {
      expect(CurrencyFormatter.formatSmart(500), equals('₹500'));
      expect(CurrencyFormatter.formatSmart(1500), equals('₹1,500'));
      expect(CurrencyFormatter.formatSmart(25000), equals('₹25,000'));
      expect(CurrencyFormatter.formatSmart(125000), equals('₹1,25,000'));
      expect(CurrencyFormatter.formatSmart(1250000), equals('₹12,50,000'));
    });

    test('formats with decimals when requested', () {
      expect(CurrencyFormatter.format(500), equals('₹500.00'));
      expect(CurrencyFormatter.format(1500), equals('₹1,500.00'));
      expect(CurrencyFormatter.format(25000), equals('₹25,000.00'));
      expect(CurrencyFormatter.format(125000), equals('₹1,25,000.00'));
      expect(CurrencyFormatter.format(1250000), equals('₹12,50,000.00'));
    });

    test('handles null, zero, and string numbers safely', () {
      expect(CurrencyFormatter.format(null), equals('₹0.00'));
      expect(CurrencyFormatter.format(0), equals('₹0.00'));
      expect(CurrencyFormatter.formatSmart(0), equals('₹0'));
      expect(CurrencyFormatter.format('45000'), equals('₹45,000.00'));
    });

    test('never produces dollar signs or foreign currency symbols', () {
      final formatted = CurrencyFormatter.format(999999);
      expect(formatted.contains('\$'), isFalse);
      expect(formatted.contains('USD'), isFalse);
      expect(formatted.startsWith('₹'), isTrue);
    });
  });

  group('Responsive Layout & Navigation Shell', () {
    testWidgets('Smoke test loads dashboard without overflows', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640)); // Small mobile phone
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FinanceApp());
      await tester.pumpAndSettle();

      expect(find.text('Executive Dashboard'), findsOneWidget);
      expect(find.text('Financial Overview'), findsOneWidget);
      expect(find.byIcon(Icons.currency_rupee_rounded), findsWidgets);
    });

    testWidgets('Navigating to Customers tab adapts to small viewport', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FinanceApp());
      await tester.pumpAndSettle();

      final customersTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Customers'),
      );
      await tester.tap(customersTab);
      await tester.pumpAndSettle();

      expect(find.text('Add Customer'), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Navigating to Payments hub tabs adapts without overflows', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FinanceApp());
      await tester.pumpAndSettle();

      final paymentsTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Payments'),
      );
      await tester.tap(paymentsTab);
      await tester.pumpAndSettle();

      expect(find.text('Payments Hub'), findsOneWidget);
      expect(find.text('Record Payment'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Payment Plans'), findsOneWidget);
      expect(find.text('Installments'), findsOneWidget);
    });

    testWidgets('Navigating to Reports screen displays INR metrics without mock data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FinanceApp());
      await tester.pumpAndSettle();

      final reportsTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Reports'),
      );
      await tester.tap(reportsTab);
      await tester.pumpAndSettle();

      expect(find.text('Financial Reports'), findsOneWidget);
      expect(find.text('Total Initial Collected'), findsOneWidget);
      expect(find.text('Average Initial Deposit'), findsOneWidget);
      expect(find.text('Active Borrowers'), findsOneWidget);
      expect(find.text('Outstanding Principal'), findsOneWidget);

      // Verify no dollar signs are rendered
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('Renders properly under 1.5x system font scaling', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Simulate system font scaling (e.g. accessibility enlargement)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.5),
            size: Size(360, 640),
          ),
          child: const FinanceApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Executive Dashboard'), findsOneWidget);
    });
  });
}
