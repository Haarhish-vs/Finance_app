import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/currency_formatter.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/navigation/screens/main_navigation_shell.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) => openUrl('GET', Uri(scheme: 'http', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => openUrl('POST', Uri(scheme: 'http', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => -1;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = Stream<List<int>>.fromIterable([
      '{"success":true,"data":{"weekdays":[],"customers":[],"loans":[],"transactions":[],"items":[]}}'
          .codeUnits,
    ]);
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

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

  group('Admin Authentication Screen', () {
    testWidgets('Renders professional Admin login screen with email and password fields',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authorized Admin Sign In'), findsOneWidget);
      expect(find.text('Admin Email or Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In as Admin'), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_rounded), findsOneWidget);
    });
  });

  group('Responsive Layout & Navigation Shell', () {
    testWidgets('Loads MainNavigationShell without overflows', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationShell(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Executive Dashboard'), findsOneWidget);
      expect(find.text('Financial Overview'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    testWidgets('Navigating to Customers tab adapts to small viewport', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationShell(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final customersTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Customers'),
      );
      await tester.tap(customersTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Add Customer'), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
    });
  });
}
