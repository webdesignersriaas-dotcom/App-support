import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Loads a network URL or a project asset path (`assets/...`).
class NetworkOrAssetImage extends StatelessWidget {
  const NetworkOrAssetImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? errorWidget;

  bool get _isAsset => url.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: Icon(Icons.person, size: width * 0.5, color: Colors.grey[400]),
        );

    if (_isAsset) {
      return Image.asset(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
