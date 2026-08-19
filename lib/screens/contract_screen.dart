import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';

/// Sözleşmedeki tek bir kalem.
class _ContractTerm {
  const _ContractTerm({required this.label, required this.value, this.tint});

  final String label;
  final String value;

  /// Vurgulanacak kalemler için renk; null ise metin birincil renkte durur.
  final Color? tint;
}

class ContractScreen extends StatefulWidget {
  const ContractScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _warning = Color(0xFFF5A623);

  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<api.PlayerContract?> _contractFuture;

  @override
  void initState() {
    super.initState();
    _contractFuture = _load();
  }

  /// P3 · `GET /careers/{cid}/player/contract`.
  Future<api.PlayerContract?> _load() async {
    final careerId = await _session.resolve();
    return _session.client.playerContract(careerId);
  }

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
      backgroundColor: ContractScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ContractScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ContractScreen._border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  // Kalem listesi kaydırılabilir, buton altta sabit: sekiz
                  // satır + iki başlık kısa telefonda ekrana sığmıyor.
                  child: Column(
                    children: [
                      const _HeaderSection(),
                      Expanded(
                        child: FutureBuilder<api.PlayerContract?>(
                          future: _contractFuture,
                          builder: (context, snapshot) {
                            // `AsyncSnapshot.hasData` yalnızca `data != null`
                            // demektir — P3 gerçekten `null` dönebildiği için
                            // (§5.2, hiç sözleşme yoksa) yüklenme durumu
                            // `connectionState`den anlaşılmalı, `hasData`'dan
                            // değil; yoksa null sonuç sonsuz döngüde takılır.
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ContractScreen._textMuted,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Sözleşme bilgisi alınamadı.',
                                    style: TextStyle(
                                      color: ContractScreen._textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final contract = snapshot.data;
                            if (contract == null) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Henüz bir sözleşmen yok.',
                                    style: TextStyle(
                                      color: ContractScreen._textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final terms = [
                              _ContractTerm(
                                label: 'Kulüp',
                                value: contract.team.name,
                              ),
                              _ContractTerm(
                                label: 'İmza tarihi',
                                value: _ddmmyyyy(contract.signedAt),
                              ),
                              _ContractTerm(
                                label: 'Sözleşme bitişi',
                                value: _ddmmyyyy(contract.expiresAt),
                              ),
                            ];
                            final earnings = [
                              _ContractTerm(
                                label: 'Haftalık maaş',
                                value: _money(contract.weeklyWage),
                              ),
                              // Türetilmiş — weekly_wage × 4, ayrı bir ödeme
                              // değil (§3.2).
                              _ContractTerm(
                                label: 'Aylık maaş',
                                value: _money(contract.monthlyWage),
                              ),
                              _ContractTerm(
                                label: 'Maç başı primi',
                                value: _money(contract.appearanceBonus),
                              ),
                              _ContractTerm(
                                label: 'Gol primi',
                                value: _money(contract.goalBonus),
                              ),
                              _ContractTerm(
                                label: 'Serbest kalma bedeli',
                                value: _money(contract.releaseClause),
                                tint: ContractScreen._warning,
                              ),
                            ];

                            return ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                const _SectionTitle(label: 'SÖZLEŞME'),
                                for (final term in terms) _TermRow(term: term),
                                const _SectionTitle(label: 'KAZANÇ'),
                                for (final term in earnings)
                                  _TermRow(term: term),
                              ],
                            );
                          },
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
                              backgroundColor: ContractScreen._accent,
                              foregroundColor: ContractScreen._textPrimary,
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

/// 'YYYY-MM-DD' → 'DD.MM.YYYY'. BE ISO-8601 verir, biçimlendirme FE'nin işi
/// (§1.3).
String _ddmmyyyy(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

/// '₺180.000' — binlik ayracı nokta, BE tam sayı verir (§1.3).
String _money(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '₺${buffer.toString()}';
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
