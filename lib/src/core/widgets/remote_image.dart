import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    required this.url,
    this.assetFallback,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    super.key,
  });

  final String? url;
  final String? assetFallback;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim() ?? '';
    final candidate = _resolveUrl(raw);
    Widget image;
    if (candidate.startsWith('http')) {
      image = Image.network(
        candidate,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
        loadingBuilder: (context, child, loading) {
          if (loading == null) return child;
          return _fallback(icon: Icons.image_rounded);
        },
      );
    } else if (candidate.startsWith('assets/')) {
      image = Image.asset(candidate,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback());
    } else if (assetFallback != null) {
      image = Image.asset(assetFallback!,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback());
    } else {
      image = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(height: height, width: width, child: image),
    );
  }

  String _resolveUrl(String raw) {
    if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('assets/')) {
      return raw;
    }
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return '${ApiClient.baseUrl}$normalized';
  }

  Widget _fallback({IconData icon = Icons.image_not_supported_rounded}) {
    return Container(
      height: height,
      width: width,
      color: AppColors.accent,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary),
    );
  }
}
