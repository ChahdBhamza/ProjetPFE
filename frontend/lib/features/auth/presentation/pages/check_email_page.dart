import 'package:flutter/material.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../widgets/auth_widgets.dart';

class CheckEmailPage extends StatefulWidget {
  final String email;
  const CheckEmailPage({super.key, required this.email});

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _autoRedirectToReset();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _autoRedirectToReset() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(
      context,
      '/reset-password',
      arguments: {'email': widget.email},
    );
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
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
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    return Transform.scale(scale: scale, child: child);
                  },
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
              ),
              const SizedBox(height: 14),
              Text(
                'Waiting for reset link',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, letterSpacing: 0.1, height: 1.05),
              ),
              const SizedBox(height: 6),
              Text(
                'A secure link was sent to:\n${widget.email}\n\nOnce clicked, this app should open and continue automatically.',
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
                    const LinearProgressIndicator(minHeight: 4, backgroundColor: Color(0x33121212)),
                    const SizedBox(height: 12),
                    Text(
                      'Listening for reset confirmation link...',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white60,
                            letterSpacing: 0.2,
                            fontSize: 11,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        if (_navigated) return;
                        _navigated = true;
                        Navigator.pushNamed(
                          context,
                          '/reset-password',
                          arguments: {'email': widget.email},
                        );
                      },
                      child: Text(
                        'Simulate link clicked (UI demo)',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white.withOpacity(0.45),
                              letterSpacing: 0.2,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const ProgressSegments(activeIndex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

