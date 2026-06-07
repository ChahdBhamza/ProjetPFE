import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../widgets/auth_widgets.dart';

class CheckEmailPage extends StatefulWidget {
  final String email;
  final String? devOtp;
  const CheckEmailPage({super.key, required this.email, this.devOtp});

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  late final TextEditingController _otpController;
  final _api = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController(text: widget.devOtp ?? '');
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Enter the 6-digit code from your email.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _api.verifyOtp(widget.email, otp);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/reset-password',
        arguments: {'email': widget.email, 'otp': otp},
      );
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
                      const SizedBox(height: 16),
                      Center(
                        child: GlassContainer(
                          width: 64,
                          height: 64,
                          borderRadius: 18,
                          opacity: 0.05,
                          child: const Center(
                            child: Icon(Icons.mark_email_unread_rounded, color: CybersightTheme.accent, size: 30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Check your email',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, letterSpacing: 0.1, height: 1.05),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A 6-digit code was sent to:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white54, height: 1.3),
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
                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                letterSpacing: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '------',
                                hintStyle: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 28,
                                  letterSpacing: 12,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: CybersightTheme.accent, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            GlowingButton(
                              label: _isLoading ? 'Verifying...' : 'Verify code',
                              textSize: 11.5,
                              darkOverlayOpacity: 0.20,
                              onTap: _isLoading ? null : _verifyCode,
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Resend code',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Colors.white38,
                                      letterSpacing: 0.2,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const ProgressSegments(activeIndex: 2),
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
