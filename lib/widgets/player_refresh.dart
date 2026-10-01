import 'package:flutter/widgets.dart';
import 'package:project_srpg/state/player_scope.dart';

/// Açıldığı anda P1'i yeniden çeker: radar gibi sunucudaki nitelik değerlerini
/// gösteren ekranlar, yerel kopya bir yanıtı kaçırmış olsa bile ekrana
/// girildiği an sunucudaki gerçek değerle çizilir.
class PlayerRefresh extends StatefulWidget {
  const PlayerRefresh({super.key, required this.child});

  final Widget child;

  @override
  State<PlayerRefresh> createState() => _PlayerRefreshState();
}

class _PlayerRefreshState extends State<PlayerRefresh> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PlayerScope.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
