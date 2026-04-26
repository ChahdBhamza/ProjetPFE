import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';

class CybersightCard extends StatelessWidget {
  final Widget child;
  const CybersightCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      opacity: 0.05,
      blur: 15,
      borderRadius: 24,
      child: child,
    );
  }
}

class CybersightInput extends StatelessWidget {
  final String label, hint;
  final IconData? icon;
  final bool isPass;
  final TextEditingController? controller;

  const CybersightInput({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.isPass = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 10, color: Colors.white38)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          obscureText: isPass,
          style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.white24) : null,
          ),
        ),
      ],
    );
  }
}

class BiometricOverrideTile extends StatelessWidget {
  final String label; final IconData icon;
  const BiometricOverrideTile({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 32),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class DottedUploadBox extends StatelessWidget {
  const DottedUploadBox({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_tilt_shift, color: CybersightTheme.accent.withOpacity(0.6), size: 36),
            const SizedBox(height: 16),
            Text('BIOMETRIC SCAN OR ID CARD', 
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

class ProgressSegments extends StatelessWidget {
  final int activeIndex;
  final int totalSegments;
  const ProgressSegments({super.key, required this.activeIndex, this.totalSegments = 3});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSegments, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 48 : 32,
          height: 3,
          decoration: BoxDecoration(
            color: isActive ? CybersightTheme.accent : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive ? [BoxShadow(color: CybersightTheme.accent.withOpacity(0.4), blurRadius: 8)] : null,
          ),
        );
      }),
    );
  }
}
