import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/scan/mode_screen.dart';
import 'ui/motion.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PhoneProofApp());
}

class PhoneProofApp extends StatelessWidget {
  const PhoneProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Motion.reduceMotion,
      builder: (context, _, __) {
        return MaterialApp(
          title: 'PhoneProof',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const ModeScreen(),
        );
      },
    );
  }
}
