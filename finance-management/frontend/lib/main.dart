import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_loading_indicator.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/navigation/screens/main_navigation_shell.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup global unauthorized callback to redirect to login screen
  ApiClient.onUnauthorized = () {
    AuthRepository().logout();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(const FinanceApp());
}

/// Root Application Widget for Finance Management App
class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

/// Authentication Gate Widget checking persistent login state on startup
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _authRepository = AuthRepository();
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final admin = await _authRepository.restoreSession();
      if (mounted) {
        setState(() {
          _isAuthenticated = admin != null;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: AppLoadingIndicator(
            message: 'Verifying admin authorization...',
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      return const MainNavigationShell();
    }

    return const LoginScreen();
  }
}
