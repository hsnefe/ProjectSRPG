import 'package:flutter/material.dart';

/// Sözleşmedeki tek bir kalem.
class _ContractTerm {
  const _ContractTerm({required this.label, required this.value, this.tint});

  final String label;
  final String value;

  /// Vurgulanacak kalemler için renk; null ise metin birincil renkte durur.
  final Color? tint;
}

class ContractScreen extends StatelessWidget {
  const ContractScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _warning = Color(0xFFF5A623);

  // Tutarlar önceden biçimlenmiş literal: statik mock veride çalışma anında
  // biçimlendirecek bir şey yok, böylece binlik ayracı yardımcısının üçüncü
  // kopyası da açılmıyor.
  static const _terms = [
    _ContractTerm(label: 'Kulüp', value: 'FK Yıldız'),
    _ContractTerm(label: 'İmza tarihi', value: '01.07.2024'),
    _ContractTerm(label: 'Sözleşme bitişi', value: '30.06.2027'),
  ];

  static const _earnings = [
    _ContractTerm(label: 'Haftalık maaş', value: '₺180.000'),
    _ContractTerm(label: 'Aylık maaş', value: '₺720.000'),
    _ContractTerm(label: 'Maç başı primi', value: '₺25.000'),
    _ContractTerm(label: 'Gol primi', value: '₺40.000'),
    _ContractTerm(
      label: 'Serbest kalma bedeli',
      value: '₺12.000.000',
      tint: _warning,
    ),
  ];

  void _showStubMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                  // Kalem listesi kaydırılabilir, buton altta sabit: sekiz
                  // satır + iki başlık kısa telefonda ekrana sığmıyor.
                  child: Column(
                    children: [
                      const _HeaderSection(),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            const _SectionTitle(label: 'SÖZLEŞME'),
                            for (final term in _terms) _TermRow(term: term),
                            const _SectionTitle(label: 'KAZANÇ'),
                            for (final term in _earnings) _TermRow(term: term),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _showStubMessage(
                              context,
                              'Sözleşme uzatma yakında',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: _textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Sözleşme Uzat'),
                          ),
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
          bottom: BorderSide(color: ContractScreen._border, width: 0.5),
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
              color: ContractScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Sözleşme',
            style: TextStyle(
              color: ContractScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: ContractScreen._accent.withValues(alpha: 0.95),
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.term});

  final _ContractTerm term;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ContractScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              term.label,
              style: const TextStyle(
                color: ContractScreen._textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            term.value,
            style: TextStyle(
              color: term.tint ?? ContractScreen._textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
