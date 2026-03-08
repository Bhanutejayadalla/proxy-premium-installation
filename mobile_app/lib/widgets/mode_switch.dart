import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../constants.dart';

class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return GestureDetector(
      onTap: state.toggleMode,
      child: Container(
        width: 140, height: 36,
        decoration: BoxDecoration(
          color: state.isFormal ? Colors.grey[200] : Colors.grey[800],
          borderRadius: BorderRadius.circular(30)
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              alignment: state.isFormal ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 65, height: 30, margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: state.isFormal ? AppColors.formalPrimary : null,
                  gradient: state.isFormal ? null : const LinearGradient(colors: [AppColors.casualPrimary, Color(0xFFF97316)]),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Center(child: Icon(state.isFormal ? LucideIcons.briefcase : LucideIcons.partyPopper, color: Colors.white, size: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }
}