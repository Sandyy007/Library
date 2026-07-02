import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'providers/member_provider.dart';
import 'providers/issue_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/search_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/report_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'utils/theme.dart';
import 'services/backend_service.dart';
import 'widgets/app_error_boundary.dart';
import 'widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The backend is started from within the app (see [BootGate]) so we can show
  // a branded splash while it boots instead of a blank window. The app itself
  // starts on the login screen and only talks to the backend at login, so
  // showing UI before the backend is ready is safe.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // On desktop we spawn the Node backend ourselves, so we must stop it when
    // the app is asked to exit (e.g. the window close button). Without this the
    // detached backend keeps running, orphaned, holding port 3000 — which also
    // prevents config/.env or app updates from taking effect on the next launch.
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _lifecycleListener = AppLifecycleListener(
        onExitRequested: () async {
          try {
            await BackendService.stopBackend();
          } catch (_) {
            // Best-effort: never block app exit on cleanup failure.
          }
          return ui.AppExitResponse.exit;
        },
      );
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  bool get _enableTooltips {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      // Desktop is the primary target for this app. Hover tooltips are
      // essential there because most toolbar actions are icon-only — without
      // them those buttons have no visible label. (Tooltips were previously
      // disabled here to work around an old Flutter desktop tooltip glitch
      // that no longer reproduces on current stable.)
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
        ChangeNotifierProvider(create: (_) => IssueProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final resolvedTheme = themeProvider.isDarkMode
              ? AppTheme.darkTheme
              : AppTheme.lightTheme;
          return MaterialApp(
            title: 'Library Management System',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => TooltipVisibility(
              visible: _enableTooltips,
              child: AppErrorBoundary(
                // AnimatedTheme tweens all colors, text styles, and
                // decorations smoothly when the user toggles dark mode
                // instead of snapping. The duration matches the
                // AppDurations.normal we use for page transitions so the
                // app feels like one cohesive motion system.
                child: AnimatedTheme(
                  data: resolvedTheme,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            home: const BootGate(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

/// Boots the backend (on Windows) behind a branded [SplashScreen], then
/// reveals the app. Shows a retry-able error state if startup fails.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

enum _BootStatus { loading, ready, error }

class _BootGateState extends State<BootGate> {
  _BootStatus _status = _BootStatus.loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (mounted) {
      setState(() {
        _status = _BootStatus.loading;
        _error = null;
      });
    }

    final startedAt = DateTime.now();
    try {
      if (Platform.isWindows) {
        final ok = await BackendService.startBackend();
        if (!ok) {
          // startBackend() returns false if it couldn't confirm the server;
          // double-check the port before declaring failure (it may still be
          // finishing its boot).
          final running = await BackendService.isBackendRunning();
          if (!running) {
            throw Exception(
              'The backend service did not start. Please make sure MySQL is '
              'running and that backend/.env is configured, then try again.',
            );
          }
        }
      }

      // Keep the splash on screen briefly so the reveal feels smooth even
      // when the backend was already running and started instantly.
      final elapsed = DateTime.now().difference(startedAt);
      const minSplash = Duration(milliseconds: 900);
      if (elapsed < minSplash) {
        await Future<void>.delayed(minSplash - elapsed);
      }

      if (!mounted) return;
      setState(() => _status = _BootStatus.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _BootStatus.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _status == _BootStatus.ready
          ? const AuthWrapper()
          : SplashScreen(
              key: ValueKey(_status),
              error: _status == _BootStatus.error ? _error : null,
              onRetry: _boot,
            ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    // Always start on LoginScreen (no session auto-restore).
    // After a successful login, AuthProvider notifies and this wrapper
    // switches to the dashboard.
    _init = Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return authProvider.isAuthenticated
                ? const DashboardScreen()
                : const LoginScreen();
          },
        );
      },
    );
  }
}
