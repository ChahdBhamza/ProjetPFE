import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;
  const ResetPasswordPage({super.key, required this.email, required this.otp});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final _api = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _api.resetPassword(widget.email, widget.otp, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline_rounded, color: CybersightTheme.ok, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Password updated — please sign in.',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ]),
          backgroundColor: const Color(0xFF151B2A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: CybersightTheme.ok.withOpacity(0.3)),
          ),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ));
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
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
                            label: _isLoading ? 'Resetting...' : 'Reset password',
                            textSize: 11.5,
                            darkOverlayOpacity: 0.20,
                            onTap: _isLoading ? null : _resetPassword,
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
