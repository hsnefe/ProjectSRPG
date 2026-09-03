import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart';

/// Bir takımın renk-temelli rozeti — gerçek kulüp logosu **yok**, oyunda
/// hiçbir yerde yok (ne backend'de ne bu paketin `assets/`'inde); elimizdeki
/// tek kimlik `color_primary`/`color_secondary` ve `short_name`.
///
/// Daire, dolgu birincil renk, 2px kenarlık ikincil renk (career_center_
/// screen.dart'ın `_TeamBadge`'iyle aynı D17 kuralı), ortada `short_name`
/// harfleri — hangi rakip olduğunu ayırt etmenin elimizdeki tek yolu bu.
///
/// **Neden ayrı bir widget, mevcut dört rozet deseninden biri değil.**
/// career_center_screen/league_table_screen/load_career_screen/
/// new_career/target_step.dart'ta zaten dört farklı desen var (kalkan
/// ikonlu daire, ikonsuz nokta, harfli gradyan kare — hiçbiri harfli
/// **daire** değil). Bu widget yalnız takvimin kullandığı yeni bir yüzey;
/// o dört ekranı buna taşımak ayrı bir iş ve onların kilitli testlerini
/// gereksiz yere riske atardı.
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.team, required this.size});

  final TeamRef team;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: team.colorPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: team.colorSecondary, width: size * 0.06),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: Text(
            team.shortName,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
