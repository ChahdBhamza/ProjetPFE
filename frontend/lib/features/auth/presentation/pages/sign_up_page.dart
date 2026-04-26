import 'package:flutter/material.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../widgets/auth_widgets.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              // 1. REGISTRATION HEADER
              GlassContainer(
                width: 70, height: 70,
                borderRadius: 16,
                opacity: 0.05,
                child: const Center(child: Icon(Icons.wifi_tethering, color: CybersightTheme.accent, size: 32)),
              ),
              const SizedBox(height: 32),
              
              // 2. TITLE SECTION
              Text('NEW OPERATOR\nREGISTRATION', 
                textAlign: TextAlign.center, 
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, height: 1.1)),
              const SizedBox(height: 12),
              Text('SECURE NEURAL GATEWAY ACCESS', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24)),
              const SizedBox(height: 48),
              
              // 3. MAIN TERMINAL CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CybersightCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CybersightInput(label: 'Full Name', hint: 'OPERATOR NAME', icon: Icons.person_outline),
                      const SizedBox(height: 24),
                      const CybersightInput(label: 'Operator ID', hint: 'CS-8829-X', icon: Icons.badge_outlined),
                      const SizedBox(height: 24),
                      const CybersightInput(label: 'Security Protocol', hint: '••••••••••••••••', icon: Icons.lock_outline, isPass: true),
                      const SizedBox(height: 32),
                      
                      // Identification Section
                      const DottedUploadBox(),
                      const SizedBox(height: 44),
                      
                      // THE ESTABLISH BUTTON
                      GlowingButton(
                        label: 'Establish Profile',
                        onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/app', (_) => false),
                      ),
                      const SizedBox(height: 48),
                      
                      // Legal Footnote
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white12, fontSize: 9, height: 1.5),
                          children: const [
                            TextSpan(text: 'BY ESTABLISHING THIS PROFILE, YOU AGREE TO THE\n'),
                            TextSpan(text: 'NEURAL DATA PRIVACY PROTOCOLS', style: TextStyle(color: CybersightTheme.accent)),
                            TextSpan(text: ' AND '),
                            TextSpan(text: 'OPERATIONAL COMPLIANCE TERMS', style: TextStyle(color: CybersightTheme.accent)),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Segmented Progress
                      const ProgressSegments(activeIndex: 0),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // 4. FOOTER TOGGLE
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(
                  text: TextSpan(
                    text: 'ALREADY REGISTERED? ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38),
                    children: const [
                      TextSpan(text: 'ACCESS GATEWAY', style: TextStyle(color: CybersightTheme.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Local widgets removed in favor of global hud_widgets and auth_widgets
