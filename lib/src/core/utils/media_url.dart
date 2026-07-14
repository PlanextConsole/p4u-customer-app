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
      if (isUploadPath(parsed.path)) {
        return '$origin${parsed.path}${parsed.hasQuery ? '?${parsed.query}' : ''}';
      }
    } catch (_) {
      return value;
    }
    return value;
  }

  final normalized = value.startsWith('/') ? value : '/$value';
  return '$origin$normalized';
}

/// Detects video media by file extension (web parity).
bool isVideoUrl(String url) {
  final clean = url.split('?').first.toLowerCase();
  return clean.endsWith('.mp4') ||
      clean.endsWith('.webm') ||
      clean.endsWith('.mov') ||
      clean.endsWith('.m4v');
}
