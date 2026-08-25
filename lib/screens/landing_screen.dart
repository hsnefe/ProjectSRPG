import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_srpg/screens/career_list_screen.dart';
import 'package:project_srpg/screens/new_career_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/glass_panel.dart';
import 'package:project_srpg/widgets/landing_menu_button.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  /// Menü hedeflerini isimli route ile yığına koyar — uygulamada route tablosu
  /// yok, ekranlar birbirini `RouteSettings.name` üzerinden arıyor.
  static void _push(BuildContext context, Widget screen, String routeName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
        settings: RouteSettings(name: routeName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/landing.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 48,
            right: 32,
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'SRPG',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  colors: [
                    Colors.white,
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    width: 320,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.fromLTRB(24, 24, 32, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LandingMenuButton(
                          label: 'New Game',
                          onTap: () => _push(
                            context,
                            const NewCareerScreen(),
                            NewCareerScreen.routeName,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LandingMenuButton(
                          label: 'Load Career',
                          onTap: () => _push(
                            context,
                            const CareerListScreen(),
                            CareerListScreen.routeName,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
