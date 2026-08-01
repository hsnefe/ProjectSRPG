import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_srpg/screens/kariyer_merkezi_screen.dart';
import 'package:project_srpg/widgets/glass_panel.dart';
import 'package:project_srpg/widgets/new_game_button.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

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
                          const Color(0xFF1E6FD9).withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.fromLTRB(24, 24, 32, 32),
                    child: NewGameButton(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const KariyerMerkeziScreen(),
                          ),
                        );
                      },
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
