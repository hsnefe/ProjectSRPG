import 'package:flutter/material.dart';

/// `event_type` (§4.5, 26 değerlik katalog) → ikon eşlemesi.
///
/// Bilinmeyen bir değer için `null` döner; `_EventCard` zaten
/// `if (event.icon != null)` ile null-safe çizim yapıyor, bu sayede
/// backend ileride listeye yeni bir tip eklediğinde FE çökmez ([İ-15]).
IconData? iconForEventType(String eventType) {
  switch (eventType) {
    // Şut sonuçları — gol.
    case 'goal':
    case 'goal_set_piece':
    case 'goal_counter':
    case 'goal_long_shot':
    case 'goal_penalty':
      return Icons.sports_soccer;

    // Şut sonuçları — kurtarış.
    case 'save':
    case 'save_set_piece':
    case 'save_counter':
    case 'save_long_shot':
    case 'save_penalty':
      return Icons.sports_handball_outlined;

    // Şut sonuçları — blok.
    case 'block':
    case 'block_set_piece':
    case 'block_counter':
    case 'block_long_shot':
      return Icons.shield_outlined;

    // Şut sonuçları — auta/dışarı.
    case 'miss':
    case 'miss_set_piece':
    case 'miss_counter':
    case 'miss_long_shot':
      return Icons.arrow_outward;

    // Duraklama / hakem / diğer.
    case 'penalty_awarded':
      return Icons.gavel;
    case 'corner':
      return Icons.flag_outlined;
    case 'foul':
      return Icons.sports_outlined;
    case 'card_yellow':
      return Icons.style_outlined;
    case 'card_red':
      return Icons.style;
    case 'substitution':
      return Icons.swap_horiz;
    case 'mentality_shift':
      return Icons.psychology_outlined;
    case 'intervention':
      return Icons.touch_app_outlined;

    default:
      return null;
  }
}
