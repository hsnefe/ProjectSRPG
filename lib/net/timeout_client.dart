import 'dart:async';

import 'package:http/http.dart' as http;

/// Her isteğe toplam süre sınırı koyan sarmalayıcı.
///
/// `http.Client` kendi başına hiç zaman aşımı uygulamaz; yanıt vermeyen bir
/// telefon içi Python (askıdan dönüş, yeniden bağlanma) ekranı sonsuza dek
/// "bekleniyor"da bırakırdı. [timeout], isteğin başından **gövdenin son
/// baytına** kadar olan toplam süredir; yanıt gövdesi bu yüzden burada tamamen
/// okunup bellekten geri verilir (API gövdeleri küçük JSON'dur).
///
/// Uzun ömürlü SSE bağlantısı bunu **kullanmaz** (`HttpMatchSseClient`):
/// keepalive aralığı kadar sessizlik orada normaldir ve gövde hiç bitmez.
///
/// Aşım `TimeoutException` fırlatır; çağıranlar bunu ağ hatasıyla aynı
/// biçimde (`SocketException` gibi) ele alır.
class TimeoutClient extends http.BaseClient {
  TimeoutClient(this._inner, {required this.timeout});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return _sendAndBuffer(request).timeout(timeout);
  }

  Future<http.StreamedResponse> _sendAndBuffer(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
