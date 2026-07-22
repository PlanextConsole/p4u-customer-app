import '../services/api_client.dart';

/// Resolves stored media URLs the same way as `p4u-new-user-web/lib/media.ts`:
/// - path-only `/uploads|/vendor-uploads|/socio-uploads` → gateway origin
/// - absolute URLs with those paths → rewrite onto gateway origin (fixes stale hosts)
String resolveMediaUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value.startsWith('assets/')) return value;
  if (value.startsWith('//')) return 'https:$value';

  final origin = Uri.parse(ApiClient.baseUrl).origin;

  bool isUploadPath(String path) =>
      path.startsWith('/uploads') ||
      path.startsWith('/vendor-uploads') ||
      path.startsWith('/socio-uploads');

  if (isUploadPath(value.startsWith('/') ? value : '/$value') &&
      !value.startsWith('http')) {
    final path = value.startsWith('/') ? value : '/$value';
    return '$origin$path';
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    try {
      final parsed = Uri.parse(value);
      final path =
          '${parsed.path}${parsed.hasQuery ? '?${parsed.query}' : ''}';
      if (isUploadPath(parsed.path)) {
        return '$origin$path';
      }
      // Stale local/dev hosts break on customer devices — rewrite onto gateway.
      if (parsed.host == 'localhost' ||
          parsed.host == '127.0.0.1' ||
          parsed.host == '0.0.0.0') {
        return '$origin$path';
      }
    } catch (_) {
      return value;
    }
    return value;
  }

  final normalized = value.startsWith('/') ? value : '/$value';
  return '$origin$normalized';
}

/// Swap admin ↔ vendor upload prefix when the first path 404s.
String? alternateUploadUrl(String url) {
  if (url.contains('/vendor-uploads/')) {
    return url.replaceFirst('/vendor-uploads/', '/uploads/');
  }
  if (url.contains('/uploads/')) {
    return url.replaceFirst('/uploads/', '/vendor-uploads/');
  }
  return null;
}

/// Detects video media by file extension (web parity).
bool isVideoUrl(String url) {
  final clean = url.split('?').first.toLowerCase();
  return clean.endsWith('.mp4') ||
      clean.endsWith('.webm') ||
      clean.endsWith('.mov') ||
      clean.endsWith('.m4v');
}
