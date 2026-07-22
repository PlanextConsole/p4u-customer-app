import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/media_url.dart';

class RemoteImage extends StatefulWidget {
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
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  late String _candidate;
  bool _triedAlternate = false;

  @override
  void initState() {
    super.initState();
    _candidate = resolveMediaUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _candidate = resolveMediaUrl(widget.url);
      _triedAlternate = false;
    }
  }

  void _onError() {
    if (!_triedAlternate) {
      final alt = alternateUploadUrl(_candidate);
      if (alt != null && alt != _candidate) {
        setState(() {
          _triedAlternate = true;
          _candidate = alt;
        });
        return;
      }
    }
    setState(() {
      _triedAlternate = true;
      _candidate = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (_candidate.startsWith('http')) {
      image = Image.network(
        _candidate,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (_, __, ___) {
          if (_candidate.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onError();
            });
          }
          return _fallback();
        },
        loadingBuilder: (context, child, loading) {
          if (loading == null) return child;
          return _fallback(icon: Icons.image_rounded);
        },
      );
    } else if (_candidate.startsWith('assets/')) {
      image = Image.asset(_candidate,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _fallback());
    } else if (widget.assetFallback != null) {
      image = Image.asset(widget.assetFallback!,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _fallback());
    } else {
      image = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
          height: widget.height, width: widget.width, child: image),
    );
  }

  Widget _fallback({IconData icon = Icons.home_work_outlined}) {
    return Container(
      height: widget.height,
      width: widget.width,
      color: const Color(0xFFE8F4F8),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary.withValues(alpha: 0.7), size: 36),
    );
  }
}
