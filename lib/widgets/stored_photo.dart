import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/photo_cache.dart';

/// One photo path for thumbnails and the full-screen viewer, including offline.
class StoredPhoto extends StatelessWidget {
  const StoredPhoto({
    super.key,
    required this.url,
    required this.fit,
    required this.placeholder,
    required this.errorBuilder,
    this.cacheWidth,
    this.label,
    this.cache,
  });
  final String url;
  final BoxFit fit;
  final Widget placeholder;
  final ImageErrorWidgetBuilder errorBuilder;
  final int? cacheWidth;
  final String? label;
  final PhotoCache? cache;
  @override
  Widget build(BuildContext context) {
    Widget local(String path) => Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      semanticLabel: label,
      excludeFromSemantics: label == null,
      errorBuilder: errorBuilder,
    );
    if (!url.startsWith('http')) return local(url);
    final photos = cache ?? PhotoCache.instance;
    return ListenableBuilder(
      listenable: photos,
      builder:
          (context, _) => FutureBuilder<File?>(
            future: photos.fileFor(url),
            builder:
                (context, snapshot) =>
                    snapshot.connectionState != ConnectionState.done
                        ? placeholder
                        : snapshot.data != null
                        ? local(snapshot.data!.path)
                        : CachedNetworkImage(
                          imageUrl: url,
                          fit: fit,
                          memCacheWidth: cacheWidth,
                          placeholder: (_, _) => placeholder,
                          imageBuilder:
                              (context, image) => Image(
                                image: image,
                                fit: fit,
                                semanticLabel: label,
                                excludeFromSemantics: label == null,
                              ),
                          errorWidget:
                              (context, _, error) =>
                                  errorBuilder(context, error, null),
                        ),
          ),
    );
  }
}
