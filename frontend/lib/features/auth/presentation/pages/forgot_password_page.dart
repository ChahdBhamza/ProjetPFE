import 'package:flutter/material.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.of(context).viewInsets.bottom;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboard > 0 ? 10 : 0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          GlassContainer(
                            width: 40,
                            height: 40,
                            borderRadius: 12,
                            opacity: 0.05,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back_rounded, size: 20),
                              color: Colors.white70,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: GlassContainer(
                          width: 62,
                          height: 62,
                          borderRadius: 18,
                          opacity: 0.05,
                          child: const Center(
                            child: Icon(Icons.lock_reset_rounded, color: CybersightTheme.accent, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Forgot password',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 28,
                              letterSpacing: 0.1,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your email and we will send you a reset link.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white54,
                              height: 1.3,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GlassContainer(
                        opacity: 0.05,
                        blur: 16,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CybersightInput(
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.alternate_email_rounded,
                              controller: _emailController,
                            ),
                            const SizedBox(height: 14),
                            GlowingButton(
                              label: 'Send reset link',
                              textSize: 11.5,
                              darkOverlayOpacity: 0.20,
                              onTap: () {
                                final email = _emailController.text.trim().isEmpty
                                    ? 'you@example.com'
                                    : _emailController.text.trim();
                                Navigator.pushNamed(
                                  context,
                                  '/check-email',
                                  arguments: {'email': email},
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const ProgressSegments(activeIndex: 2),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Back to sign in',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white54,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

