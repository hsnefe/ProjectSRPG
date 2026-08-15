import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'match_models.dart';

/// `GET /matches/{id}/stream`'e bağlanırken/bağlandıktan sonra oluşan hata
/// (§9.1) — 404 `match_not_found`, 410 `match_finished`, SSE `event: error`
/// (`internal`) veya bağlantı kopması.
class MatchStreamException implements Exception {
  MatchStreamException(this.statusCode, {this.code, this.message});

  /// SSE `event: error` frame'inden geliyorsa `null` (HTTP durum kodu yok).
  final int? statusCode;
  final String? code;
  final String? message;

  @override
  String toString() =>
      'MatchStreamException($statusCode, code: $code, message: $message)';
}

/// SSE akışından gelen tek bir mesaj.
///
/// Bu turda yalnızca `tick` çerçeveleri UI'a taşınır; `intervention_offer`
/// ve `error` (ve gelecekte tanımlanabilecek başka her tür) [MatchStreamIgnored]
/// olarak sessizce elden geçer — motor yanıtlanmayan bir teklifi kendi 180s
/// güvenlik zaman aşımıyla `decline` edip akışı sürdürür (§7.2), bu yüzden
/// burada özel bir işlem gerekmez.
sealed class MatchStreamMessage {
  const MatchStreamMessage();
}

class MatchTickMessage extends MatchStreamMessage {
  const MatchTickMessage(this.tick);

  final TickFrame tick;
}

class MatchStreamIgnored extends MatchStreamMessage {
  const MatchStreamIgnored(this.eventType, this.raw);

  final String eventType;
  final Map<String, dynamic> raw;
}

/// `MatchController`'ın test edilebilmesi için soyutlanmış SSE kaynağı —
/// gerçek HTTP olmadan sahte bir akış enjekte edilebilir.
abstract class MatchStreamSource {
  Stream<MatchStreamMessage> connect(Uri uri);
}

/// `HttpMatchSseClient` — `text/event-stream` formatını (`id:`/`event:`/
/// `data:`, boş satırda dispatch, `:`-ile-başlayan keepalive yorumları,
/// §2.2) elle ayrıştıran gerçek implementasyon. Paket eklemeye gerek yok,
/// format bu kadarıyla basit.
class HttpMatchSseClient implements MatchStreamSource {
  HttpMatchSseClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  @override
  Stream<MatchStreamMessage> connect(Uri uri) async* {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/event-stream';
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      final bodyBytes = await streamedResponse.stream.toBytes();
      throw _errorFromBody(streamedResponse.statusCode, bodyBytes);
    }

    String? currentEvent;
    final dataBuffer = StringBuffer();

    final lines = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        final message = _dispatch(currentEvent, dataBuffer.toString());
        currentEvent = null;
        dataBuffer.clear();
        if (message != null) yield message;
        continue;
      }
      if (line.startsWith(':')) continue; // keepalive yorumu
      if (line.startsWith('event:')) {
        currentEvent = line.substring('event:'.length).trim();
      } else if (line.startsWith('data:')) {
        if (dataBuffer.isNotEmpty) dataBuffer.writeln();
        dataBuffer.write(line.substring('data:'.length).trim());
      }
      // `id:` alanı zarfın `seq`'iyle aynıdır (data içinde de var) — bu
      // turda reconnect/replay kapsam dışı olduğu için ayrıca tutulmuyor.
    }
  }

  MatchStreamMessage? _dispatch(String? eventType, String data) {
    if (data.isEmpty) return null;
    final raw = jsonDecode(data) as Map<String, dynamic>;
    final type = eventType ?? 'message';
    if (type == 'tick') {
      return MatchTickMessage(TickFrame.fromJson(raw));
    }
    if (type == 'error') {
      throw MatchStreamException(
        null,
        code: raw['code'] as String?,
        message: raw['message'] as String?,
      );
    }
    return MatchStreamIgnored(type, raw);
  }

  MatchStreamException _errorFromBody(int statusCode, List<int> bodyBytes) {
    try {
      final body =
          jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
      return MatchStreamException(
        statusCode,
        code: body['code'] as String?,
        message: body['message'] as String?,
      );
    } catch (_) {
      return MatchStreamException(statusCode, message: utf8.decode(bodyBytes));
    }
  }
}
