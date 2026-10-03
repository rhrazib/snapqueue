import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/sync/background_sync.dart';
import 'core/sync/sync_coordinator.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/camera/presentation/bloc/camera_bloc.dart';
import 'features/camera/presentation/pages/camera_preview_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppColors.background,
    ),
  );

  await configureDependencies();
  try {
    await BackgroundSync.init();
    await BackgroundSync.registerSafetyNet();
  } catch (e) {
    // The foreground coordinator still syncs while the app is open.
    debugPrint('Background sync setup failed: $e');
  }
  sl<SyncCoordinator>().start();

  runApp(const SnapQueueApp());
}

class SnapQueueApp extends StatelessWidget {
  const SnapQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapQueue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: BlocProvider(
        create: (_) => sl<CameraBloc>()..add(const CameraStarted()),
        child: const CameraPreviewScreen(),
      ),
    );
  }
}
