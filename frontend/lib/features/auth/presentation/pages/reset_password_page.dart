import 'package:flutter/material.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 10),
                child: Column(
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
                        width: 64,
                        height: 64,
                        borderRadius: 18,
                        opacity: 0.05,
                        child: const Center(
                          child: Icon(Icons.verified_user_rounded, color: CybersightTheme.accent, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Set new password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, letterSpacing: 0.1, height: 1.05),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Account: ${widget.email}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white54),
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
                            label: 'New password',
                            hint: '••••••••••',
                            icon: Icons.lock_outline_rounded,
                            isPass: true,
                            controller: _passwordController,
                          ),
                          const SizedBox(height: 10),
                          CybersightInput(
                            label: 'Confirm password',
                            hint: '••••••••••',
                            icon: Icons.lock_outline_rounded,
                            isPass: true,
                            controller: _confirmController,
                          ),
                          const SizedBox(height: 14),
                          GlowingButton(
                            label: 'Reset password',
                            textSize: 11.5,
                            darkOverlayOpacity: 0.20,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password reset successful (mock)')),
                              );
                              Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const ProgressSegments(activeIndex: 2),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

