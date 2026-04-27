import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../widgets/auth_widgets.dart';
import '../providers/auth_provider.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all identification fields.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
    );

    if (success && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/app', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
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
                      CybersightInput(
                        controller: _nameController,
                        label: 'Full Name', 
                        hint: 'OPERATOR NAME', 
                        icon: Icons.person_outline
                      ),
                      const SizedBox(height: 24),
                      CybersightInput(
                        controller: _emailController,
                        label: 'Operator ID', 
                        hint: 'CS-8829-X (Email)', 
                        icon: Icons.badge_outlined
                      ),
                      const SizedBox(height: 24),
                      CybersightInput(
                        controller: _passwordController,
                        label: 'Security Protocol', 
                        hint: '••••••••••••••••', 
                        icon: Icons.lock_outline, 
                        isPass: true
                      ),
                      
                      if (authProvider.errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          authProvider.errorMessage!,
                          style: const TextStyle(color: CybersightTheme.warning, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 32),
                      
                      // THE ESTABLISH BUTTON
                      GlowingButton(
                        label: authProvider.isLoading ? 'SYNCING...' : 'Establish Profile',
                        onTap: authProvider.isLoading ? () {} : () => _handleSignUp(),
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
                  text: const TextSpan(
                    text: 'ALREADY REGISTERED? ',
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                    children: [
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
