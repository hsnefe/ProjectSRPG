import 'package:flutter/material.dart';

class DialogScreen extends StatelessWidget {
  const DialogScreen({
    super.key,
    required this.contactName,
    required this.message,
    required this.choices,
  });

  final String contactName;
  final String message;
  final List<String> choices;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        24;

    return Scaffold(
      backgroundColor: _surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: panelHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        _PhotoSection(contactName: contactName),
                        _MessageSection(message: message),
                        Expanded(
                          child: _ChoicesSection(choices: choices),
                        ),
                      ],
                    ),
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

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.contactName});

  final String contactName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const ColoredBox(
            color: DialogScreen._surface1,
            child: SizedBox.expand(),
          ),
          const Icon(
            Icons.person_outline,
            size: 40,
            color: DialogScreen._textMuted,
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DialogScreen._surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                contactName,
                style: const TextStyle(
                  color: DialogScreen._textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageSection extends StatelessWidget {
  const _MessageSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: DialogScreen._border, width: 0.5),
          bottom: BorderSide(color: DialogScreen._border, width: 0.5),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: const TextStyle(
          color: DialogScreen._textPrimary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }
}

class _ChoicesSection extends StatelessWidget {
  const _ChoicesSection({required this.choices});

  final List<String> choices;

  void _onChoiceTap(BuildContext context, String choice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Yanıt gönderildi'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          for (var i = 0; i < choices.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _onChoiceTap(context, choices[i]),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DialogScreen._textPrimary,
                  side: const BorderSide(color: DialogScreen._border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  alignment: Alignment.centerLeft,
                  textStyle: const TextStyle(fontSize: 13, height: 1.4),
                ),
                child: Text(choices[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
