import 'package:flutter/material.dart';

String? normalizeApiImageUrl(String? rawUrl) {
  if (rawUrl == null) return null;

  var trimmed = rawUrl.trim();
  if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 1) {
    trimmed = trimmed.substring(1, trimmed.length - 1).trim();
  }
  trimmed = trimmed.replaceAll(r'\/', '/').replaceAll('\\u002F', '/');
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('gs://')) return null;

  final withScheme = trimmed.startsWith('//')
      ? 'https:$trimmed'
      : ((!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))
            ? (trimmed.startsWith('www.') ||
                      trimmed.startsWith('res.cloudinary.com/'))
                  ? 'https://$trimmed'
                  : trimmed
            : trimmed);

  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  return uri.toString();
}

class CarApiImage extends StatelessWidget {
  final String? imageUrl;
  final String fallbackAssetPath;
  final double? height;
  final double? width;
  final BoxFit fit;

  const CarApiImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAssetPath,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl?.trim();

    if (raw != null && raw.startsWith('assets/images/')) {
      return Image.asset(raw, height: height, width: width, fit: fit);
    }

    final normalized = normalizeApiImageUrl(imageUrl);

    if (normalized == null) {
      return Image.asset(
        fallbackAssetPath,
        height: height,
        width: width,
        fit: fit,
      );
    }

    return Image.network(
      normalized,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return SizedBox(
          height: height,
          width: width,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          fallbackAssetPath,
          height: height,
          width: width,
          fit: fit,
        );
      },
    );
  }
}
