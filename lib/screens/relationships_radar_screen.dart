import 'package:flutter/material.dart';
import 'package:project_srpg/widgets/radar_chart.dart';

class RelationshipsRadarScreen extends StatelessWidget {
  const RelationshipsRadarScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFFE85D5D);

  static const _labels = ['Cazibe', 'Kibarlık', 'Özgüven','Zeka', 'Beceriklilik'];
  static const _values = [74.0, 58.0, 51.0, 63.0, 29.0];

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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                        child: RadarChart(
                          labels: _labels,
                          values: _values,
                          accentColor: _accent,
                          gridShape: RadarGridShape.circle,
                          backgroundColor: _surface2,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Text(
                          'Çevrendeki bağların genel dengesi. Merkeze yakın eksenler ilgi ister.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textMuted, fontSize: 12),
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
            color: RelationshipsRadarScreen._border,
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
              color: RelationshipsRadarScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'İlişki Haritası',
            style: TextStyle(
              color: RelationshipsRadarScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
