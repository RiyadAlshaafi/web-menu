import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void agentLog(String hypothesisId, String location, String message, Map<String, Object?> data) {
  // #region agent log
  try {
    final payload = jsonEncode({
      'sessionId': 'a74a61',
      'runId': 'pre-fix',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    globalContext.callMethod(
      'fetch'.toJS,
      'http://127.0.0.1:7527/ingest/d9af8a63-8da2-46ef-8993-c2f159432196'.toJS,
      {
        'method': 'POST',
        'headers': {
          'Content-Type': 'application/json',
          'X-Debug-Session-Id': 'a74a61',
        },
        'body': payload,
      }.jsify(),
    );
  } catch (_) {}
  // #endregion
}

void agentLogResources(String hypothesisId) {
  // #region agent log
  try {
    final performance = globalContext['performance'] as JSObject?;
    if (performance == null) return;
    final entries = performance.callMethod('getEntriesByType'.toJS, 'resource'.toJS) as JSArray<JSObject>;
    final buckets = <String, Map<String, num>>{
      for (final name in ['engine', 'appJs', 'deferred', 'fonts', 'images', 'supabase', 'other'])
        name: {'count': 0, 'bytes': 0, 'ms': 0},
    };
    final slow = <Map<String, Object?>>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final raw = _str(entry, 'name');
      final uri = Uri.tryParse(raw);
      final safe = uri == null ? 'unknown' : '${uri.host}${uri.path}';
      final bytes = _num(entry, 'transferSize');
      final decoded = _num(entry, 'decodedBodySize');
      final ms = _num(entry, 'duration');
      final bucket = _bucket(safe);
      final row = buckets[bucket]!;
      row['count'] = row['count']! + 1;
      row['bytes'] = row['bytes']! + (bytes > 0 ? bytes : decoded);
      row['ms'] = row['ms']! + ms;
      slow.add({'path': safe, 'bytes': bytes > 0 ? bytes : decoded, 'ms': ms.round(), 'bucket': bucket});
    }
    slow.sort((a, b) => ((b['bytes'] as num?) ?? 0).compareTo((a['bytes'] as num?) ?? 0));
    agentLog(hypothesisId, 'agent_log_web.dart:resources', 'guest resource totals', {
      'buckets': buckets.map((key, value) => MapEntry(key, {
            'count': value['count']!.round(),
            'bytes': value['bytes']!.round(),
            'ms': value['ms']!.round(),
          })),
      'largest': slow.take(8).toList(),
      'partCount': buckets['deferred']!['count']!.round(),
    });
  } catch (_) {}
  // #endregion
}

String _bucket(String path) {
  final lower = path.toLowerCase();
  if (lower.contains('canvaskit') || lower.contains('skwasm') || lower.contains('flutter.js')) return 'engine';
  if (lower.contains('.part.js')) return 'deferred';
  if (lower.contains('main.dart.js')) return 'appJs';
  if (lower.contains('fonts.g') || lower.contains('gstatic') && lower.contains('font')) return 'fonts';
  if (lower.contains('supabase.co')) return 'supabase';
  if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.contains('/storage/')) {
    return 'images';
  }
  return 'other';
}

String _str(JSObject object, String key) {
  final value = object[key];
  if (value == null || value.isUndefinedOrNull) return '';
  return (value as JSString).toDart;
}

double _num(JSObject object, String key) {
  final value = object[key];
  if (value == null || value.isUndefinedOrNull) return 0;
  return (value as JSNumber).toDartDouble;
}
