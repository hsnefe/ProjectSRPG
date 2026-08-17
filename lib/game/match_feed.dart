import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Bir maç olayının hangi tarafa ait olduğu.
///
/// [MatchSide.neutral] hakem kararları, devre araları gibi tarafsız
/// satırlar için kullanılır; yorum akışında gri ve ortalanmış çizilir.
enum MatchSide { home, away, neutral }

/// Yorum akışındaki tek bir satır.
class MatchEvent {
  const MatchEvent({
    required this.minute,
    required this.side,
    required this.text,
    this.isGoal = false,
    this.icon,
    this.eventType,
  });

  /// Olayın kaçıncı dakikada olduğu. Skorborddaki saat bu değeri izler.
  final int minute;

  final MatchSide side;
  final String text;

  /// True ise skorbord [side]'a göre güncellenir.
  final bool isGoal;

  /// Metnin önünde çizilen opsiyonel ikon (kart, değişiklik, korner...).
  final IconData? icon;

  /// API'nin `event_type` alanı (§4.5) — yalnızca gerçek maçlardan gelen
  /// olaylarda dolu; [icon] zaten bundan türetilip önceden hesaplanır, bu
  /// alan bilgi/hata ayıklama amaçlıdır.
  final String? eventType;
}

/// Yorum akışının oynatma hızı.
///
/// Skorborddaki dakika butonu bu üç kademe arasında sırayla dolaşır, yani
/// her üç basışta başlangıçtaki [MatchSpeed.slow] kademesine geri döner.
enum MatchSpeed {
  slow('Yavaş', 'slow', 1, 0),
  medium('Orta', 'medium', 0.5, 1),
  fast('Hızlı', 'fast', 0.25, 2);

  const MatchSpeed(this.label, this.wire, this.tickScale, this.arrows);

  final String label;

  /// `POST /matches/{id}/speed`'in `speed` alanına yazılan ad — backend'deki
  /// `MatchSpeedLevel` literal'ıyla (`api/schemas/common.py`) aynı olmalı.
  final String wire;

  /// Feed'in temel bekleme süresi bu katsayıyla çarpılır. Yalnızca yerel
  /// [ScriptedMatchFeed] kullanır; gerçek maçta tempoyu sunucu belirler ve
  /// aynı katsayılar backend'in `config.SPEED_SCALES`'inde yaşar.
  final double tickScale;

  /// Butonda koşu ikonunun yanında çizilen sağ ok sayısı.
  final int arrows;

  MatchSpeed get next => values[(index + 1) % values.length];
}

/// Maç olaylarını üreten kaynak.
///
/// Şimdilik yerel senaryo ([ScriptedMatchFeed]) çalışıyor; ileride FastAPI
/// üstündeki maç motoru aynı arayüzü uygulayacak (ör. SSE/WebSocket dinleyen
/// bir `RemoteMatchFeed`). Ekran tarafı yalnızca bu arayüzü tanıdığı için
/// kaynak değiştiğinde `match_screen.dart` değişmez.
abstract class MatchFeed {
  /// Maç boyunca üretilen olayları sırayla yayınlar.
  ///
  /// [speed] verilirse akış hızı oyun sırasında değiştirilebilir; değer her
  /// olaydan önce yeniden okunur. Hız kavramı olmayan kaynaklar yok sayabilir.
  Stream<MatchEvent> events({ValueListenable<MatchSpeed>? speed});
}

/// Sabit bir senaryoyu verilen aralıklarla tek tek yayınlar.
class ScriptedMatchFeed implements MatchFeed {
  const ScriptedMatchFeed({
    this.script = kDemoMatchScript,
    this.tick = const Duration(milliseconds: 1800),
  });

  final List<MatchEvent> script;

  /// İki satır arasındaki bekleme. Testler [Duration.zero] verebilir.
  final Duration tick;

  @override
  Stream<MatchEvent> events({ValueListenable<MatchSpeed>? speed}) async* {
    for (final event in script) {
      final scale = (speed?.value ?? MatchSpeed.slow).tickScale;
      await Future<void>.delayed(tick * scale);
      yield event;
    }
  }
}

/// Prototip maç senaryosu: FK Yıldız (ev) - Deniz SK (deplasman).
const List<MatchEvent> kDemoMatchScript = [
  MatchEvent(
    minute: 0,
    side: MatchSide.neutral,
    text: 'Başlama vuruşu — FK Yıldız topla oyunu açıyor.',
    icon: Icons.sports_soccer,
  ),
  MatchEvent(
    minute: 2,
    side: MatchSide.home,
    text: 'Top Efe Kaan\'a düşüyor, sağ kanattan alan arıyor.',
  ),
  MatchEvent(
    minute: 3,
    side: MatchSide.home,
    text: 'Efe Kaan\'dan Barış\'a güzel bir pas.',
  ),
  MatchEvent(
    minute: 5,
    side: MatchSide.away,
    text: 'Deniz SK topu kesti, hızlı kontra başlıyor.',
  ),
  MatchEvent(
    minute: 6,
    side: MatchSide.away,
    text: 'Volkan\'ın ortası savunmaya çarpıp taca çıktı.',
  ),
  MatchEvent(
    minute: 8,
    side: MatchSide.neutral,
    text: 'Korner — Deniz SK.',
    icon: Icons.flag_outlined,
  ),
  MatchEvent(
    minute: 9,
    side: MatchSide.away,
    text: 'Kornerde kafayı vuran Serkan\'ın vuruşu direğin dibinden auta.',
  ),
  MatchEvent(
    minute: 13,
    side: MatchSide.home,
    text: 'Efe Kaan iki rakip arasından sıyrıldı, ceza sahasına giriyor!',
  ),
  MatchEvent(
    minute: 14,
    side: MatchSide.home,
    text: 'Şut! Kaleci köşeye uzanıp kurtardı.',
    icon: Icons.sports_handball_outlined,
  ),
  MatchEvent(
    minute: 18,
    side: MatchSide.away,
    text: 'Deniz SK orta sahada topa sahip olmaya başladı.',
  ),
  MatchEvent(
    minute: 21,
    side: MatchSide.neutral,
    text: 'Faul — orta sahada oyun duruyor.',
    icon: Icons.sports_outlined,
  ),
  MatchEvent(
    minute: 24,
    side: MatchSide.home,
    text: 'Barış sol kanattan ortaladı, top savunmadan döndü.',
  ),
  MatchEvent(
    minute: 27,
    side: MatchSide.home,
    text: 'GOL! Efe Kaan ceza sahası dışından muhteşem bir vuruşla ağları '
        'havalandırdı!',
    isGoal: true,
    icon: Icons.sports_soccer,
  ),
  MatchEvent(
    minute: 31,
    side: MatchSide.away,
    text: 'Deniz SK baskıyı artırdı, iki pas arayla ceza sahasına yaklaştı.',
  ),
  MatchEvent(
    minute: 34,
    side: MatchSide.away,
    text: 'Volkan\'ın sert şutu üstten auta gitti.',
  ),
  MatchEvent(
    minute: 38,
    side: MatchSide.neutral,
    text: 'Sarı kart — Deniz SK, Serkan.',
    icon: Icons.style_outlined,
  ),
  MatchEvent(
    minute: 42,
    side: MatchSide.home,
    text: 'Efe Kaan pres yaparak topu kazandı ama pas kaçtı.',
  ),
  MatchEvent(
    minute: 45,
    side: MatchSide.neutral,
    text: 'Devre arası — FK Yıldız 1-0 önde.',
    icon: Icons.timer_outlined,
  ),
  MatchEvent(
    minute: 46,
    side: MatchSide.neutral,
    text: 'İkinci yarı başladı.',
    icon: Icons.sports_soccer,
  ),
  MatchEvent(
    minute: 49,
    side: MatchSide.away,
    text: 'Deniz SK yüksek tempoyla başladı, sağ kanadı zorluyor.',
  ),
  MatchEvent(
    minute: 53,
    side: MatchSide.away,
    text: 'GOL! Volkan ceza sahası içinde topu ağlara gönderdi.',
    isGoal: true,
    icon: Icons.sports_soccer,
  ),
  MatchEvent(
    minute: 57,
    side: MatchSide.home,
    text: 'FK Yıldız cevap arıyor, Efe Kaan derinlere koşuyor.',
  ),
  MatchEvent(
    minute: 60,
    side: MatchSide.neutral,
    text: 'Oyuncu değişikliği — Deniz SK.',
    icon: Icons.swap_horiz,
  ),
  MatchEvent(
    minute: 64,
    side: MatchSide.home,
    text: 'Barış\'ın ortasında Efe Kaan\'ın kafa vuruşu az farkla dışarı.',
  ),
  MatchEvent(
    minute: 68,
    side: MatchSide.away,
    text: 'Deniz SK topu ceza sahası önünde çevirip zaman kazanıyor.',
  ),
  MatchEvent(
    minute: 72,
    side: MatchSide.neutral,
    text: 'Korner — FK Yıldız.',
    icon: Icons.flag_outlined,
  ),
  MatchEvent(
    minute: 73,
    side: MatchSide.home,
    text: 'Kornerde karambol! Top çizgiden çıkarıldı.',
  ),
  MatchEvent(
    minute: 78,
    side: MatchSide.home,
    text: 'Efe Kaan sağdan içeri kat etti, şutu blokladı savunma.',
  ),
  MatchEvent(
    minute: 83,
    side: MatchSide.away,
    text: 'Deniz SK kontraatakta sayısal üstünlüğü kullanamadı.',
  ),
  MatchEvent(
    minute: 87,
    side: MatchSide.home,
    text: 'GOL! Efe Kaan son vuruşta takımını öne geçirdi!',
    isGoal: true,
    icon: Icons.sports_soccer,
  ),
  MatchEvent(
    minute: 90,
    side: MatchSide.neutral,
    text: 'Uzatma: 3 dakika.',
    icon: Icons.timer_outlined,
  ),
  MatchEvent(
    minute: 92,
    side: MatchSide.away,
    text: 'Son atak Deniz SK\'da, ortası kaleci tarafından yakalandı.',
  ),
  MatchEvent(
    minute: 93,
    side: MatchSide.neutral,
    text: 'Maç bitti — FK Yıldız 2-1 Deniz SK.',
    icon: Icons.sports_score_outlined,
  ),
];
