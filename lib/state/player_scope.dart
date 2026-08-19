import 'package:flutter/material.dart';
import 'package:project_srpg/state/player_state.dart';

/// [PlayerState]'i ağaca yayar. Uygulamanın en üstünde, [MaterialApp]'in
/// üzerinde bir kez kurulur.
class PlayerScope extends StatefulWidget {
  const PlayerScope({super.key, required this.child});

  final Widget child;

  /// Çağıran widget'ı state değişimlerine abone eder.
  static PlayerState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_PlayerScopeInherited>();
    assert(scope != null, 'PlayerScope bulunamadı. Ağacın üstüne ekleyin.');
    return scope!.notifier!;
  }

  @override
  State<PlayerScope> createState() => _PlayerScopeState();
}

class _PlayerScopeState extends State<PlayerScope> {
  final PlayerState _state = PlayerState();

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: PlayerState.load() bittiğinde notifyListeners() çağırır,
    // bunu dinleyen her ekran kendiliğinden yeniden çizilir — burada bir
    // Future beklemeye gerek yok.
    _state.load();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerScopeInherited(
      notifier: _state,
      child: widget.child,
    );
  }
}

class _PlayerScopeInherited extends InheritedNotifier<PlayerState> {
  const _PlayerScopeInherited({
    required PlayerState super.notifier,
    required super.child,
  });
}
