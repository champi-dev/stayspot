import 'package:flutter/material.dart';
import 'package:stayspot/app/theme.dart';

/// Drop-in network image with loading/error states.
///
/// Uses Image.network (Flutter's in-memory cache) instead of
/// cached_network_image: flutter_cache_manager's disk layer hangs
/// forever in Android release builds for this app, leaving eternal
/// placeholder spinners.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: AppColors.surface,
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textTertiary),
              ),
            ),
      errorBuilder: (context, error, stack) => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.image_not_supported,
              size: 32, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
