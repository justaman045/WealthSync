import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar backed by a remote URL that degrades gracefully: a neutral
/// placeholder while loading and the bundled [asset] when the remote image
/// fails (a bare `CachedNetworkImageProvider` shows a broken-image box).
class AppAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final Widget? overlay;
  final String asset;

  const AppAvatar({
    super.key,
    this.url,
    this.size = 60,
    this.overlay,
    this.asset = 'assets/profile.png',
  });

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final Widget image;
    if (url == null || url.isEmpty) {
      image = Image.asset(asset, fit: BoxFit.cover);
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          alignment: Alignment.center,
          color: Colors.black.withValues(alpha: 0.04),
          child: const Icon(Icons.person, color: Colors.black38, size: 30),
        ),
        errorWidget: (_, __, ___) => Image.asset(asset, fit: BoxFit.cover),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: overlay == null
            ? image
            : Stack(
                fit: StackFit.expand,
                children: [image, Center(child: overlay!)],
              ),
      ),
    );
  }
}