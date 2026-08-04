import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'root_shell.dart';
import 'providers/menu_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => MenuProvider(),
      child: const SwiftBiteApp(),
    ),
  );
}

class SwiftBiteApp extends StatelessWidget {
  const SwiftBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftBite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kCanvas,
        textTheme: appTextTheme(),
        colorScheme: const ColorScheme.dark(
          primary: kBrand,
          surface: kSurface,
        ),
      ),
      home: const RootShell(),
    );
  }
}
