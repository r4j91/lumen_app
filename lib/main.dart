import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/auth_screen.dart';
import 'screens/today_screen.dart';
import 'screens/upcoming_screen.dart';
// HOME-V2-OLD: import 'screens/browse_screen.dart';
import 'screens/home_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/inbox_screen.dart';
import 'services/auth_service.dart';
import 'services/haptic_service.dart';
import 'services/notification_service.dart';
import 'services/task_sync.dart';
import 'widgets/responsive_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
  runApp(const StackedApp());
}

/// Evita acessar [Supabase.instance] antes do init ou após falha silenciosa.
bool _supabaseReady = false;

Future<void> _bootstrap() async {
  await initializeDateFormatting('pt_BR', null);

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await ThemeProvider.instance.loadSaved();
  HapticService();

  try {
    await NotificationService().initialize();
  } catch (e, st) {
    debugPrint('NotificationService init failed: $e\n$st');
  }

  try {
    await Supabase.initialize(
      url: 'https://gbpoenvogrcqhcqfjldd.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdicG9lbnZvZ3JjcWhjcWZqbGRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1Mjg1NTEsImV4cCI6MjA5NzEwNDU1MX0.xLTHtA1e1ia3s-2kwezcwIAD170b7Bc0L1fCTeNJNXM',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    _supabaseReady = true;
  } catch (e, st) {
    debugPrint('Supabase init failed: $e\n$st');
  }
}

class StackedApp extends StatelessWidget {
  const StackedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) {
        final colors = ThemeProvider.instance.colors;
        return MaterialApp(
          title: 'Stacked',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildFrom(colors),
          home: const _AuthGate(),
        );
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _auth = AuthService();
  StreamSubscription<AuthState>? _authSub;
  DateTime? _lastTokenRefresh;
  int _rapidRefreshCount = 0;

  @override
  void initState() {
    super.initState();
    if (_supabaseReady) _listenAuthRecovery();
  }

  /// Detecta rajada de refresh (ex.: 5 abas disparando queries em paralelo)
  /// e faz signOut para evitar loop que derruba o app no device.
  void _listenAuthRecovery() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.tokenRefreshed) {
        final now = DateTime.now();
        if (_lastTokenRefresh != null &&
            now.difference(_lastTokenRefresh!) < const Duration(seconds: 2)) {
          _rapidRefreshCount++;
          if (_rapidRefreshCount >= 5) {
            _rapidRefreshCount = 0;
            debugPrint('Auth: refresh storm detected, signing out');
            unawaited(Supabase.instance.client.auth.signOut());
          }
        } else {
          _rapidRefreshCount = 0;
        }
        _lastTokenRefresh = now;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _rapidRefreshCount = 0;
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supabaseReady) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              const SizedBox(height: 16),
              Text(
                'Conectando…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            Supabase.instance.client.auth.currentSession == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) return const RootScreen();
        return const AuthScreen();
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _todayKey = GlobalKey<TodayScreenState>();
  final _inboxKey = GlobalKey<InboxScreenState>();

  // Lazy — monta aba só na primeira visita; evita rajada de queries no boot.
  final List<Widget?> _screens = List<Widget?>.filled(5, null);

  Widget _lazyScreen(int i) {
    if (_screens[i] != null) return _screens[i]!;
    _screens[i] = switch (i) {
      0 => HomeScreen(key: _homeKey, onNavigateToTab: _onTabSelected),
      1 => InboxScreen(key: _inboxKey),
      2 => TodayScreen(key: _todayKey),
      3 => const UpcomingScreen(),
      4 => const FiltersScreen(),
      _ => const SizedBox.shrink(),
    };
    return _screens[i]!;
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
    _lazyScreen(0);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onTabSelected(int i) {
    if (i == _index) {
      switch (i) {
        case 1: _inboxKey.currentState?.scrollToTop(); break;
        case 2: _todayKey.currentState?.scrollToTop(); break;
      }
      return;
    }
    // HOME-REFRESH: voltando pra tab Home a partir de outra — recarrega
    // tarefas/projetos (mesma necessidade de Inbox/Today ao reentrar,
    // sem RouteObserver: troca de tab não passa pelo Navigator).
    _lazyScreen(i);
    if (i == 0) _homeKey.currentState?.reload();
    setState(() => _index = i);
  }

  void _onTaskCreated() {
    TaskSync.instance.notifyChanged();
  }

  void _onProjectCreated() {
    _homeKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedIndex: _index,
      onDestinationSelected: _onTabSelected,
      body: IndexedStack(
        index: _index,
        children: List.generate(
          5,
          (i) => _screens[i] ?? const SizedBox.shrink(),
        ),
      ),
      onTaskCreated: _onTaskCreated,
      onProjectCreated: _onProjectCreated,
    );
  }
}
