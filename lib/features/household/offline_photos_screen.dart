import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pantry_provider.dart';
import '../../services/photo_cache.dart';
import '../../widgets/pantry_data_state.dart';

class OfflinePhotosScreen extends StatefulWidget {
  const OfflinePhotosScreen({super.key});
  @override
  State<OfflinePhotosScreen> createState() => _OfflinePhotosScreenState();
}

class _OfflinePhotosScreenState extends State<OfflinePhotosScreen> {
  Future<void> _refresh() async {
    final pantry = context.read<PantryProvider>();
    await PhotoCache.instance.sync([
      ...pantry.allItems.map((i) => i.imageUrl),
      ...pantry.allShoppingItems.map((i) => i.imageUrl),
    ], force: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline photos')),
    body: PantryDataState(
      child: ListenableBuilder(
        listenable: PhotoCache.instance,
        builder: (context, _) {
          final cache = PhotoCache.instance;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Product photos are saved on this device for every home, including shopping items. A photo you choose yourself is saved when you attach it.',
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  cache.total == 0
                      ? 'No online photos to download. Add a product photo in the batch editor.'
                      : '${cache.ready} of ${cache.total} online photos saved offline.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (cache.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Saving offline photos',
                  ),
                ),
              if (cache.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(liveRegion: true, child: Text(cache.error!)),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: cache.busy ? null : _refresh,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Retry downloads'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
