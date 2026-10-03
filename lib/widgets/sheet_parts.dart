import 'package:flutter/material.dart';

import 'product_image.dart';

/// The top of an item editor: the product photo beside its barcode.
class ProductHeader extends StatelessWidget {
  const ProductHeader({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.barcode,
  });

  final String name;
  final String? imageUrl;
  final String? barcode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final barcode = this.barcode;

    return Row(
      children: [
        ProductImage(imageUrl: imageUrl, size: 96, viewerTitle: name),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Barcode',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              if (barcode == null)
                Text(
                  'None · added by hand',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                SelectableText(
                  barcode,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled row in an item editor, with its control on the trailing edge.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.child,
    this.detail,
  });

  final String label;
  final Widget child;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                if (detail != null) ...[const SizedBox(height: 4), detail],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
