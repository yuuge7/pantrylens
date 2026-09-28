import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imageUrl, this.size = 64});

  final String? imageUrl;
  final double size;

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

    return ClipRRect(
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
  }
}
