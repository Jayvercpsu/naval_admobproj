import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'services/cart_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the app locked to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Try loading the environment settings
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    debugPrint(
      "Warning: Could not load assets/.env: $e",
    );
  }

  // Start up Firebase (Lab Activity 5).
  // Wrapped in try/catch so the app still runs (DummyJSON login still
  // works) even before `flutterfire configure` has been run.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
      "Warning: Firebase failed to initialize: $e",
    );
  }

  // Start the Naval application
  runApp(const NavalAdvMobProg());
}

class NavalAdvMobProg extends StatelessWidget {
  const NavalAdvMobProg({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme changes stay available everywhere
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        // Cart data stays shared across screens
        ChangeNotifierProvider(
          create: (_) => CartService(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(412, 715),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (buildContext, child) {
          final themeModel =
              buildContext.watch<ThemeProvider>();

          return MaterialApp(
            title: 'E-Commerce App',
            debugShowCheckedModeBanner: false,
            theme: themeModel.lightTheme,
            darkTheme: themeModel.darkTheme,
            themeMode: themeModel.isDark
                ? ThemeMode.dark
                : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) =>
                  const SplashScreen(),
              '/sign': (context) =>
                  const SignScreen(),
              '/signup': (context) =>
                  const SignupScreen(),
              '/home': (context) =>
                  const HomeScreen(),
              '/settings': (context) =>
                  const SettingsScreen(),
              '/chat': (context) =>
                  const ChatScreen(),
            },
          );
        },
      ),
    );
  }
}
