import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/design_system/cybersight_theme.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/pages/sign_up_page.dart';
import 'features/auth/presentation/pages/auth_success_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/check_email_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/app/presentation/pages/app_shell.dart';
import 'features/app/presentation/pages/save_success_page.dart';
import 'package:provider/provider.dart';
import 'features/app/presentation/providers/detection_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DetectionProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const CybersightApp(),
    ),
  );
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class CybersightApp extends StatelessWidget {
  const CybersightApp({super.key});

  Route<dynamic> _buildAnimatedRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubicEmphasized);
        return FadeTransition(
          opacity: Tween<double>(begin: 0.55, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.028),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.992, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cybersight AI',
      debugShowCheckedModeBanner: false,
      theme: CybersightTheme.darkTheme,
      scrollBehavior: const _NoStretchScrollBehavior(),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _buildAnimatedRoute(settings, const SplashPage());
          case '/signin':
            return _buildAnimatedRoute(settings, const SignInPage());
          case '/signup':
            return _buildAnimatedRoute(settings, const SignUpPage());
          case '/auth-success':
            return _buildAnimatedRoute(settings, const AuthSuccessPage());
          case '/forgot-password':
            return _buildAnimatedRoute(settings, const ForgotPasswordPage());
          case '/check-email':
            final args = settings.arguments as Map<String, dynamic>?;
            final email = (args?['email'] as String?) ?? 'you@example.com';
            return _buildAnimatedRoute(settings, CheckEmailPage(email: email));
          case '/reset-password':
            final args = settings.arguments as Map<String, dynamic>?;
            final email = (args?['email'] as String?) ?? 'you@example.com';
            return _buildAnimatedRoute(settings, ResetPasswordPage(email: email));
          case '/app':
            return _buildAnimatedRoute(settings, const AppShell());
          case '/save-success':
            return _buildAnimatedRoute(settings, const SaveSuccessPage());
          case '/detection-success':
            return _buildAnimatedRoute(settings, const DetectionSuccessPage());
          default:
            return _buildAnimatedRoute(settings, const SplashPage());
        }
      },
    );
  }
}