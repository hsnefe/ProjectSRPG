import 'package:flutter/material.dart';
import 'package:project_srpg/screens/career_center_screen.dart';

/// Maç sonrası talep ekranı — şimdilik yer tutucu. Maç ekranındaki "İlerle"
/// butonu buraya `pushReplacement` ile geçer, buradan da kariyer merkezine
/// dönülür. İçerik ilerleyen turlarda doldurulacak.
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);

  /// Yığındaki mevcut kariyer merkezine döner; maç öncesi/maç ekranları atılır.
  /// `route.isFirst` güvenlik ağı: kariyer merkezi yığında yoksa (izole test,
  /// ileride farklı bir giriş noktası) tüm yığın boşaltılmasın.
  void _openCareerCenter(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == CareerCenterScreen.routeName || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _HeaderSection(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 40, 24, 40),
                        child: Text(
                          'Maç sonrası talepler yakında.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openCareerCenter(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textPrimary,
                              side: const BorderSide(color: _border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            icon: const Icon(Icons.home_outlined, size: 16),
                            label: const Text('Kariyer Merkezi'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: RequestScreen._border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: RequestScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Talepler',
            style: TextStyle(
              color: RequestScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
