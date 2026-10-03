import 'package:flutter/material.dart';

import '../screens/photo_viewer.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.viewerTitle,
  });

  final String? imageUrl;
  final double size;

  /// When set, tapping the photo opens it full screen under this title.
  /// Large photos also show a corner badge to hint at it.
  final String? viewerTitle;

  static const double _badgeMinSize = 80;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: colors.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: size * 0.4,
        color: colors.onSecondaryContainer,
      ),
    );
    final url = imageUrl;
    final viewerTitle = this.viewerTitle;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(
        dimension: size,
        child:
            url == null
                ? placeholder
                : Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  // Show the placeholder until the first frame decodes.
                  frameBuilder:
                      (_, child, frame, wasSynchronouslyLoaded) =>
                          wasSynchronouslyLoaded || frame != null
                              ? child
                              : placeholder,
                  errorBuilder: (_, _, _) => placeholder,
                ),
      ),
    );
    if (url == null || viewerTitle == null) return image;

    return Semantics(
      button: true,
      label: 'View photo of $viewerTitle',
      child: GestureDetector(
        onTap:
            () => PhotoViewer.open(context, imageUrl: url, title: viewerTitle),
        child:
            size < _badgeMinSize
                ? image
                : Stack(
                  children: [
                    image,
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
