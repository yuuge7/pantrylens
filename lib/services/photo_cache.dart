import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'error_reporter.dart';

/// Persistent product photos, outside the OS's evictable image cache.
/// Downloads are bounded, atomic, deduplicated and never block database writes.
class PhotoCache extends ChangeNotifier {
  PhotoCache({Future<Directory> Function()? directory, http.Client? client})
    : _directory = directory ?? _defaultDirectory,
      _client = client ?? http.Client();
  static final instance = PhotoCache();
  static const maxBytes = 8 * 1024 * 1024;
  final Future<Directory> Function() _directory;
  final http.Client _client;
  final _files = <String, Future<File?>>{};
  final _attempts = <String, DateTime>{};
  Future<void>? _sync;
  bool busy = false;
  int total = 0, ready = 0;
  String? error;
  static Future<Directory> _defaultDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/product-photos',
  );
  bool _remote(String url) =>
      {'http', 'https'}.contains(Uri.tryParse(url)?.scheme);
  Future<File> _target(String url) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/${sha256.convert(utf8.encode(url))}.img');
  }

  Future<File?> fileFor(String url) => _files.putIfAbsent(url, () async {
    if (!_remote(url)) return null;
    try {
      final file = await _target(url);
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  });

  Future<void> sync(Iterable<String?> images, {bool force = false}) async {
    // Each caller eventually gets its own current URL set, even during a scan.
    final urls = images.whereType<String>().where(_remote).toSet().toList();
    final job = (_sync ?? Future<void>.value()).then(
      (_) => _download(urls, force),
    );
    _sync = job;
    try {
      await job;
    } finally {
      if (identical(_sync, job)) _sync = null;
    }
  }

  Future<void> _download(List<String> urls, bool force) async {
    busy = true;
    total = urls.length;
    ready = 0;
    error = null;
    notifyListeners();
    var next = 0;
    Future<void> worker() async {
      while (next < urls.length) {
        final url = urls[next++];
        try {
          if (await fileFor(url) != null) {
            ready++;
            continue;
          }
          final attempt = _attempts[url];
          if (!force &&
              attempt != null &&
              DateTime.now().difference(attempt) < const Duration(minutes: 15))
            continue;
          _attempts[url] = DateTime.now();
          final response = await _client
              .send(http.Request('GET', Uri.parse(url)))
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200 ||
              (response.contentLength ?? 0) > maxBytes) {
            await response.stream.listen((_) {}).cancel();
            throw const HttpException('Product photo could not be downloaded');
          }
          final bytes = <int>[];
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 8),
          )) {
            if (bytes.length + chunk.length > maxBytes)
              throw const HttpException('Product photo exceeds 8 MB');
            bytes.addAll(chunk);
          }
          // Reject HTML/error bodies rather than pinning an unusable photo forever.
          final image =
              bytes.length >= 12 &&
              ((bytes[0] == 0xff && bytes[1] == 0xd8) ||
                  (bytes[0] == 0x89 &&
                      bytes[1] == 0x50 &&
                      bytes[2] == 0x4e &&
                      bytes[3] == 0x47) ||
                  ascii
                      .decode(bytes.take(6).toList(), allowInvalid: true)
                      .startsWith('GIF8') ||
                  (ascii.decode(bytes.take(4).toList(), allowInvalid: true) ==
                          'RIFF' &&
                      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) ==
                          'WEBP'));
          if (!image)
            throw const FormatException(
              'Product photo response was not an image',
            );
          final target = await _target(url);
          final pending = File('${target.path}.part');
          await pending.writeAsBytes(bytes, flush: true);
          await pending.rename(target.path);
          _files[url] = Future.value(target);
          ready++;
        } catch (e, stack) {
          error =
              'Some photos are not available offline. Check your connection and retry.';
          unawaited(ErrorReporter.capture(e, stack));
        }
      }
    }

    try {
      await Future.wait([worker(), worker()]);
    } finally {
      busy = false;
      if (ready < total)
        error ??=
            'Some photos are not available offline. Check your connection and retry.';
      notifyListeners();
    }
  }
}
