import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isometric/common/core/config/model_config.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/features/camera/presentation/screens/camera_run.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the two models used for subject separation and depth-of-field in
  // the background while the camera starts.
  ModelLoader.instance.preloadBokehModels().catchError((e) {
    debugPrint('Model loading warning: $e');
  });

  // Enforce pure black status bar and navigation bar for dark camera experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.pureBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const IsometricApp());
}

class IsometricApp extends StatelessWidget {
  const IsometricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Isometric Camera',
      debugShowCheckedModeBanner: false,
      // Black & Greys dark mode theme with Open Sans fonts
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const CameraRun(),
    );
  }
}
