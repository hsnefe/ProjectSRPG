import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:project_srpg/screens/landing_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

void main() {
  runApp(const MyApp());
}

/// Fareyle sürükleyerek kaydırmayı açar.
///
/// Varsayılan davranış masaüstü ve web'de yalnızca dokunma ve kalemi tanır, o
/// yüzden yatay şeritler hiç kaymıyordu: dikey tekerlek yatay eksende sıfır
/// delta üretip olayı dıştaki dikey listeye bırakıyor, fare sürüklemesi de
/// baştan yok sayılıyordu. Tek tek her şeride sarmak yerine uygulamanın tamamı
/// için bir kez tanımlanıyor.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PlayerScope(
      child: MaterialApp(
        title: 'Project SRPG',
        scrollBehavior: const AppScrollBehavior(),
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const LandingScreen(),
      ),
    );
  }
}
