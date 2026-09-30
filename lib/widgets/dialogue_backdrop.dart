import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Konuşmanın **nerede** geçtiği. Bir diyalog artık boş bir degradenin önünde
/// değil, olayın yerinde geçiyor: takım yemeği kafede, röportaj basın
/// odasında, antrenör konuşması soyunma odasında.
///
/// Sahne sosyal olayın kendisinden gelir (`content/social_offers.py`'nin
/// şablonları) ya da ilişki türünden; ikisi de FE'nin sunum kararı (§5.8),
/// backend sahne göndermez.
enum DialogueScene {
  trainingGround,
  lockerRoom,
  cafe,
  pressRoom,
  home,
  stadium,
  tunnel,
  teamBus,
  clubOffice,
  clinic,
  restaurant,
  park,
  gym,
  shop,
  fanStreet,
}

/// Günün saati. Yalnızca gün ışığının girdiği (pencere / açık hava) sahnelerde
/// anlamı var; pencere­siz odalar (soyunma odası, basın odası, tünel) tek
/// görselle çizilir ve bu değeri yok sayar.
///
/// Oyunda saat kavramı yok (yalnızca `game_date`, bkz. `daytime.py`) — bu yüzden
/// değer durumdan türetilmiyor, sahnenin doğal saati varsayılan ([_BackdropSpec])
/// ve çağıran isterse ezer.
enum BackdropTime { day, dusk, night }

/// Sahnenin refah durumu; yalnızca iki sahnenin iki hâli var: ev (`lean` =
/// mütevazı, `thriving` = lüks) ve stadyum (`lean` = boş, `thriving` = dolu).
/// Diğer sahneler bu değeri yok sayar.
///
/// Durumu neyin belirleyeceği (para, şöhret, kulüp ligi…) henüz karara
/// bağlanmadı; o yüzden bu bir parametre, hesaplanan bir değer değil.
enum BackdropStatus { lean, thriving }

class _BackdropSpec {
  const _BackdropSpec(
    this.stem, {
    this.timed = true,
    this.defaultTime = BackdropTime.day,
    this.tiers,
    this.defaultStatus = BackdropStatus.lean,
  });

  /// `assets/images/backgrounds/<stem>[_<tier>][_<time>].jpg`
  final String stem;
  final bool timed;
  final BackdropTime defaultTime;

  /// (lean, thriving) dosya eki; null ise sahnenin seviyesi yok.
  final (String, String)? tiers;
  final BackdropStatus defaultStatus;
}

const _specs = <DialogueScene, _BackdropSpec>{
  DialogueScene.trainingGround: _BackdropSpec('training_ground'),
  DialogueScene.lockerRoom: _BackdropSpec('locker_room', timed: false),
  DialogueScene.cafe: _BackdropSpec('cafe', defaultTime: BackdropTime.dusk),
  DialogueScene.pressRoom: _BackdropSpec('press_room', timed: false),
  DialogueScene.home: _BackdropSpec(
    'home',
    defaultTime: BackdropTime.dusk,
    tiers: ('modest', 'luxury'),
  ),
  DialogueScene.stadium: _BackdropSpec(
    'stadium',
    defaultTime: BackdropTime.night,
    tiers: ('empty', 'full'),
    defaultStatus: BackdropStatus.thriving,
  ),
  DialogueScene.tunnel: _BackdropSpec('tunnel', timed: false),
  DialogueScene.teamBus: _BackdropSpec('team_bus', defaultTime: BackdropTime.dusk),
  DialogueScene.clubOffice: _BackdropSpec('club_office'),
  DialogueScene.clinic: _BackdropSpec('clinic'),
  DialogueScene.restaurant: _BackdropSpec('restaurant', defaultTime: BackdropTime.night),
  DialogueScene.park: _BackdropSpec('park', defaultTime: BackdropTime.dusk),
  DialogueScene.gym: _BackdropSpec('gym'),
  DialogueScene.shop: _BackdropSpec('shop'),
  DialogueScene.fanStreet: _BackdropSpec('fan_street', defaultTime: BackdropTime.dusk),
};

/// Sahnenin render edilmiş arka plan dosyası. Dosya adları
/// `tools/blender/build_dialogue_backdrops.py`'den geliyor; orada bir sahne
/// yalnızca `_<time>` alıyorsa burada da `timed` olmalı.
String backdropAssetFor(
  DialogueScene scene, {
  BackdropTime? time,
  BackdropStatus? status,
}) {
  final spec = _specs[scene]!;
  final parts = [spec.stem];
  final tiers = spec.tiers;
  if (tiers != null) {
    final s = status ?? spec.defaultStatus;
    parts.add(s == BackdropStatus.thriving ? tiers.$2 : tiers.$1);
  }
  if (spec.timed) parts.add((time ?? spec.defaultTime).name);
  return 'assets/images/backgrounds/${parts.join('_')}.jpg';
}

/// Sahnenin zemin katmanı: Blender'da render edilmiş arka plan
/// ([backdropAssetFor]). Dosya yoksa ya da henüz yüklenmediyse altta duran
/// prosedürel siluet görünür — amaç konuşmanın nerede geçtiğinin bir bakışta
/// okunması, fotogerçekçilik değil.
class DialogueBackdrop extends StatelessWidget {
  const DialogueBackdrop({
    super.key,
    required this.scene,
    required this.tint,
    this.time,
    this.status,
  });

  final DialogueScene scene;
  final Color tint;

  /// Null ise sahnenin doğal saati ([_BackdropSpec.defaultTime]).
  final BackdropTime? time;

  /// Null ise sahnenin varsayılan durumu; bkz. [BackdropStatus].
  final BackdropStatus? status;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Yedek: görsel yüklenene kadar (ya da hiç yüklenemezse) bu görünür.
        CustomPaint(painter: _BackdropPainter(scene, tint), size: Size.infinite),
        Image.asset(
          backdropAssetFor(scene, time: time, status: status),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        // İlişkinin tonu, renderın üstünde yalnızca iz kadar: altı karakter
        // katmanı, üstü sahneyi kartın rengiyle akraba kılan yer.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint.withValues(alpha: 0.14), tint.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.scene, this.tint);

  final DialogueScene scene;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Her sahne kendi iki rengiyle başlıyor; ilişkinin tonu yalnızca üstüne
    // ince bir yıkama olarak geliyor, yoksa altı sahne altı farklı renk
    // olurdu ve mekân okunmazdı.
    final (top, bottom, accent) = _palette();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );

    switch (scene) {
      case DialogueScene.trainingGround:
        _horizon(canvas, w, h, 0.58, const Color(0xFF1F4A2C));
        // Yan çizgi ve orta daire parçası.
        final line = Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(0, h * 0.74), Offset(w, h * 0.74), line);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w / 2, h * 1.05), width: w * 0.7, height: h * 0.5),
          math.pi, math.pi, false, line,
        );
        // Uzakta kale.
        _goal(canvas, w * 0.5, h * 0.56, w * 0.22, h * 0.1);

      case DialogueScene.lockerRoom:
        _horizon(canvas, w, h, 0.66, const Color(0xFF1A1E27));
        // Dolap sırası ve askıdaki formalar.
        for (var i = 0; i < 5; i++) {
          final x = w * (0.08 + i * 0.21);
          canvas.drawRect(
            Rect.fromLTWH(x, h * 0.16, w * 0.16, h * 0.5),
            Paint()..color = const Color(0xFF2A3140),
          );
          canvas.drawRect(
            Rect.fromLTWH(x + w * 0.03, h * 0.26, w * 0.1, h * 0.3),
            Paint()..color = accent.withValues(alpha: 0.5),
          );
        }
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.66, w, h * 0.08),
          Paint()..color = const Color(0xFF39404E),
        );

      case DialogueScene.cafe:
        _horizon(canvas, w, h, 0.72, const Color(0xFF2A2018));
        // Arkada pencereler, önde masa kenarı.
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(w * (0.08 + i * 0.3), h * 0.12, w * 0.22, h * 0.42),
              const Radius.circular(6),
            ),
            Paint()..color = const Color(0xFF3D3322),
          );
        }
        canvas.drawCircle(
            Offset(w * 0.5, h * 0.08), h * 0.06, Paint()..color = const Color(0x55F5A623));
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.84, w, h * 0.16),
          Paint()..color = const Color(0xFF4A3B29),
        );

      case DialogueScene.pressRoom:
        _horizon(canvas, w, h, 0.78, const Color(0xFF171A21));
        // Sponsor duvarı: tekrar eden bloklar.
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 4; col++) {
            canvas.drawRect(
              Rect.fromLTWH(
                  w * (0.04 + col * 0.245), h * (0.1 + row * 0.22), w * 0.18, h * 0.1),
              Paint()..color = accent.withValues(alpha: row.isEven ? 0.22 : 0.12),
            );
          }
        }
        // Mikrofonlu masa.
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.78, w, h * 0.22),
          Paint()..color = const Color(0xFF2B303B),
        );

      case DialogueScene.home:
        _horizon(canvas, w, h, 0.74, const Color(0xFF251E28));
        // Lamba ışığı, bir pencere, bir raf.
        canvas.drawRect(
          Rect.fromLTWH(w * 0.62, h * 0.1, w * 0.3, h * 0.4),
          Paint()..color = const Color(0xFF1A2333),
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.06, h * 0.42, w * 0.3, h * 0.06),
          Paint()..color = const Color(0xFF3A2F26),
        );
        canvas.drawCircle(
          Offset(w * 0.2, h * 0.2),
          h * 0.16,
          Paint()..color = const Color(0x33F5A623),
        );

      case DialogueScene.stadium:
        _horizon(canvas, w, h, 0.52, const Color(0xFF1B4029));
        // Tribün: iki bant nokta.
        final rnd = math.Random(4);
        for (var i = 0; i < 140; i++) {
          canvas.drawCircle(
            Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.48),
            1.6,
            Paint()..color = Colors.white.withValues(alpha: 0.10 + rnd.nextDouble() * 0.2),
          );
        }
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.48, w, h * 0.05),
          Paint()..color = const Color(0xFF0E1116),
        );

      // Yeni sahneler render görselleriyle geliyor; yedek siluet bunlar için
      // yalnızca zemin düzlemi — ayrıntı çizmenin anlamı yok, render yüklenince
      // zaten üstünü kaplıyor.
      case DialogueScene.tunnel:
      case DialogueScene.teamBus:
      case DialogueScene.clubOffice:
      case DialogueScene.clinic:
      case DialogueScene.restaurant:
      case DialogueScene.park:
      case DialogueScene.gym:
      case DialogueScene.shop:
      case DialogueScene.fanStreet:
        _horizon(canvas, w, h, 0.72, const Color(0xFF1A1E27));
    }

    // İlişkinin tonu — ince, yalnızca sahneyi kartın rengiyle akraba kılacak
    // kadar. Üstte yoğun, altta yok: karakter katmanı altta duruyor.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withValues(alpha: 0.22), tint.withValues(alpha: 0.02)],
        ).createShader(Offset.zero & size),
    );
  }

  /// Zemin düzlemi — her sahnenin ortak iskeleti.
  void _horizon(Canvas canvas, double w, double h, double at, Color floor) {
    canvas.drawRect(Rect.fromLTWH(0, h * at, w, h * (1 - at)), Paint()..color = floor);
  }

  void _goal(Canvas canvas, double cx, double cy, double gw, double gh) {
    final paint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: gw, height: gh), paint);
  }

  (Color, Color, Color) _palette() => switch (scene) {
        DialogueScene.trainingGround =>
          (const Color(0xFF2A4257), const Color(0xFF1B3324), AppColors.success),
        DialogueScene.lockerRoom =>
          (const Color(0xFF242A36), const Color(0xFF12151B), AppColors.accent),
        DialogueScene.cafe =>
          (const Color(0xFF3A2E22), const Color(0xFF1E1813), AppColors.warning),
        DialogueScene.pressRoom =>
          (const Color(0xFF1F2530), const Color(0xFF0E1116), AppColors.danger),
        DialogueScene.home =>
          (const Color(0xFF2E2433), const Color(0xFF17131A), Color(0xFF9B5CF6)),
        DialogueScene.stadium =>
          (const Color(0xFF14203A), const Color(0xFF0E1116), AppColors.warning),
        _ => (const Color(0xFF242A36), const Color(0xFF12151B), AppColors.accent),
      };

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.scene != scene || old.tint != tint;
}
