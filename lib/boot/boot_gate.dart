import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'python_host.dart';

/// [PythonHost] hazır olana dek splash gösterir, sonra [child]'ı açar.
///
/// Gömülü back-end olmayan hedeflerde ev sahibi baştan hazırdır ve bu widget
/// doğrudan [child]'ı döndürür — splash hiç görünmez.
class BootGate extends StatefulWidget {
  const BootGate({super.key, required this.child, this.host});

  final Widget child;

  /// Testlerde sahte ev sahibi; boşsa [PythonHost.instance].
  final PythonHost? host;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late final PythonHost _host = widget.host ?? PythonHost.instance;

  @override
  void initState() {
    super.initState();
    _host.start();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _host,
      builder: (context, _) {
        if (_host.isReady) return widget.child;
        return _Splash(host: _host);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({required this.host});

  final PythonHost host;

  @override
  Widget build(BuildContext context) {
    final failed = host.phase == BootPhase.failed;
    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed) const CircularProgressIndicator(),
              if (failed) const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 24),
              Text(
                failed ? 'Oyun motoru başlatılamadı' : 'Oyun hazırlanıyor…',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (failed) ...[
                const SizedBox(height: 8),
                Text(
                  host.error ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (host.canRetry)
                  FilledButton(
                    onPressed: host.retry,
                    child: const Text('Tekrar dene'),
                  )
                else
                  const Text(
                    'Uygulamayı kapatıp yeniden açın.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
