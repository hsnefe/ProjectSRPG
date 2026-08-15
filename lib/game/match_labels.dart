/// `situation` (§3.3, 8 değer) ve `mentality` (§3.4, 5 değer) için Türkçe
/// görünen adlar. Contract bu görüntü metinlerini sağlamıyor — FE kararı.
library;

const Map<String, String> situationLabels = {
  'balanced': 'Dengeli',
  'home_slightly_better': 'Ev sahibi hafif üstün',
  'away_slightly_better': 'Deplasman hafif üstün',
  'home_dominating': 'Ev sahibi baskın',
  'away_dominating': 'Deplasman baskın',
  'chaotic': 'Karışık oyun',
  'parking_bus': 'Kale önü kilit',
  'all_out_attack': 'Her şey hücum',
};

const Map<String, String> mentalityLabels = {
  'park_the_bus': 'Kale önü kilit',
  'defensive': 'Defansif',
  'balanced': 'Dengeli',
  'attacking': 'Hücumcu',
  'all_out_attack': 'Her şey hücum',
};

/// Bilinmeyen bir kod gelirse (forward-compat) ham kodu olduğu gibi gösterir.
String situationLabel(String code) => situationLabels[code] ?? code;

String mentalityLabel(String code) => mentalityLabels[code] ?? code;
