/// Türkçe'ye göre büyük harfe çevirir.
///
/// Dart'ın `toUpperCase()`'i yerelden bağımsızdır: `'i'` → `'I'` verir, yani
/// 'Sevgili' ekranda 'SEVGILI' olur. Türkçe'de noktalı i'nin büyüğü noktalı
/// İ (U+0130); noktasız ı'nın büyüğü zaten I olduğu için onu `toUpperCase()`
/// doğru çeviriyor, elle düzeltilmesi gereken tek harf i.
///
/// Arayüz Türkçe olduğu ve `category.toUpperCase()` birden fazla ekranda
/// geçtiği için tek sahipte duruyor.
String trUpperCase(String value) => value.replaceAll('i', 'İ').toUpperCase();
