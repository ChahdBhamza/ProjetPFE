import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final _api = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final devOtp = await _api.forgotPassword(email);
      if (!mounted) return;
      Navigator.pushNamed(context, '/check-email', arguments: {
        'email': email,
        if (devOtp != null) 'dev_otp': devOtp,
      });
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not connect to server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: const Color(0xFF151B2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x33FF6B6B)),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ));
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
                        'Enter your email and we will send you a 6-digit reset code.',
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
                              label: _isLoading ? 'Sending...' : 'Send reset code',
                              textSize: 11.5,
                              darkOverlayOpacity: 0.20,
                              onTap: _isLoading ? null : _sendResetCode,
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
