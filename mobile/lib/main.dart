import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/app/router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: StaySpotApp()));
}

class StaySpotApp extends ConsumerStatefulWidget {
  const StaySpotApp({super.key});

  @override
  ConsumerState<StaySpotApp> createState() => _StaySpotAppState();
}

class _StaySpotAppState extends ConsumerState<StaySpotApp> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state on app startup
    Future.microtask(() {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StaySpot',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
