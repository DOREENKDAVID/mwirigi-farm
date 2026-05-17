import 'package:flutter/material.dart';

import 'core/service/api_service.dart';
import 'core/util/responsive.dart';
import 'offline/connectivity/connectivity_service.dart';
import 'offline/connectivity/offline_banner.dart';
import 'offline/database/local_database.dart';
import 'offline/repositories/cow_repository.dart';
import 'offline/sync/sync_queue.dart';
import 'offline/sync/sync_status_page.dart';
import 'screens/admin_create_user_screen.dart';
import 'screens/crop_details_screen.dart';
import 'screens/dairy_screen.dart';
import 'screens/kpi_screen.dart';
import 'screens/layers_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/ngushish/ngushish_page.dart';

/// Singleton local database. Held in a top-level variable so the
/// repositories + sync queue can share one connection without
/// passing it through the widget tree.
late final LocalDatabase offlineDb;

Future<void> _bootOfflineStack() async {
  offlineDb = LocalDatabase();
  await ConnectivityService.instance.start();
  await SyncQueue.instance.start(offlineDb);
  await CowRepository.instance.init(offlineDb);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootOfflineStack();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mwirigi Farm',
      // Used by ApiService to redirect to /auth from outside a widget
      // when a 401 indicates the session has expired or the token is invalid.
      navigatorKey: ApiService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF27500A)),
        useMaterial3: true,
      ),
      // Clamp the system text scaler so accessibility users with extreme
      // font scaling (>130%) don't overflow fixed-height widgets, while
      // still allowing a small bump for readability. Wraps every screen
      // in the OfflineBanner so the connectivity / sync state is visible
      // app-wide without each route opting in individually.
      builder: (context, child) {
        final clamped = clampedTextScaler(context, child);
        return OfflineBanner(child: clamped);
      },
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const LoginScreen(),
        '/auth': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/kpi': (context) => const KpiScreen(),
        '/layers': (context) => const LayersScreen(),
        '/dairy': (context) => const DairyScreen(),
        '/ngushish': (context) => Scaffold(
              backgroundColor: const Color(0xFFF5F4F0),
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF27500A),
                title: const Text(
                  'Ngushish Farm',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              body: const NgushishPage(),
            ),
        '/admin/users': (context) => const AdminCreateUserScreen(),
        '/sync': (context) => const SyncStatusPage(),
      },
      // /ngushish/:id — navigated to from the crop register's "View
      // details" action. Uses onGenerateRoute since the path carries a
      // dynamic segment that the named-routes table can't match.
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/ngushish/')) {
          final id = name.substring('/ngushish/'.length);
          if (id.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => CropDetailsScreen(cropId: id),
            );
          }
        }
        return null;
      },
    );
  }
}
