import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A product photo on its own screen, with pinch and double-tap zoom.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewer(imageUrl: imageUrl, title: title),
      ),
    );
  }

  /// Open Food Facts serves 400 px photos by default and keeps the original
  /// beside them; other addresses are returned unchanged.
  static String fullSizeUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.host.endsWith('openfoodfacts.org')) return imageUrl;
    return imageUrl.replaceFirst(RegExp(r'\.\d+\.jpg$'), '.full.jpg');
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  static const double _doubleTapScale = 2.5;

  final _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    // Keep the tapped point under the finger while zooming in.
    final shift = _doubleTapPosition * (1 - _doubleTapScale);
    _transform.value =
        Matrix4.identity()
          ..translateByDouble(shift.dx, shift.dy, 0, 1)
          ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  Widget _photo(String url, ImageErrorWidgetBuilder errorBuilder) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      semanticLabel: 'Photo of ${widget.title}',
      loadingBuilder:
          (context, child, progress) =>
              progress == null
                  ? child
                  : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
      errorBuilder: errorBuilder,
    );
  }

  Widget _unavailable(BuildContext context, Object _, StackTrace? _) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          Text(
            'Photo unavailable. Check your connection.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullSizeUrl = PhotoViewer.fullSizeUrl(widget.imageUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: GestureDetector(
        onDoubleTapDown:
            (details) => _doubleTapPosition = details.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          maxScale: 6,
          child: SizedBox.expand(
            child: _photo(
              fullSizeUrl,
              // The original may be missing; fall back to the stored photo.
              fullSizeUrl == widget.imageUrl
                  ? _unavailable
                  : (_, _, _) => _photo(widget.imageUrl, _unavailable),
            ),
          ),
        ),
      ),
    );
  }
}
