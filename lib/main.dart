import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: App starting...');
  
  // Non-blocking initialization for heavy services
  Future.microtask(() async {
    try {
      print('DEBUG: Initializing notifications...');
      await NotificationService.instance.init();
      print('DEBUG: Scheduling streak reminder...');
      await NotificationService.instance.scheduleStreakReminder();
      print('DEBUG: All initializations complete.');
    } catch (e) {
      print('DEBUG: Error during initialization: $e');
    }
  });

  // Force edge-to-edge and set initial black nav bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const ProviderScope(child: OwnWordsApp()));
}

class OwnWordsApp extends StatelessWidget {
  const OwnWordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OwnWords',
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Container(
          color: Colors.black, // Solid Black area for the system nav bar globally
          child: SafeArea(
            top: false,
            bottom: true, // Keep UI strictly above the bottom system bar globally
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      // Instant screen transitions — eliminate all animation lag
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return const RootShell();
          },
        );
      },
      home: const RootShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen();
  }
}
