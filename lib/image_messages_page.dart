import 'package:flutter/material.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

class ImageMessagesPage extends StatefulWidget {
  const ImageMessagesPage({super.key, required this.api});

  final GameApi api;

  @override
  State<ImageMessagesPage> createState() => _ImageMessagesPageState();
}

class _ImageMessagesPageState extends State<ImageMessagesPage> {
  late Future<List<ImageMessage>> _messages;

  @override
  void initState() {
    super.initState();
    _messages = widget.api.imageMessages();
  }

  Future<void> _refresh() async {
    final request = widget.api.imageMessages();
    setState(() => _messages = request);
    await request;
  }

  void _open(ImageMessage message) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _ImageMessageViewer(message: message)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پیغام‌های تصویری')),
    body: ScreenBackground(
      child: FutureBuilder<List<ImageMessage>>(
        future: _messages,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: appRed,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'دریافت پیغام‌های تصویری ناموفق بود.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            );
          }

          final messages = snapshot.data ?? const <ImageMessage>[];
          if (messages.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز پیغام تصویری‌ای منتشر نشده است.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .76,
              ),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(message),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'image-message-${message.id}',
                            child: Image.network(
                              message.url,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: appRed,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (message.title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Text(
                              message.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: appInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );
}

class _ImageMessageViewer extends StatelessWidget {
  const _ImageMessageViewer({required this.message});

  final ImageMessage message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(message.title.isEmpty ? 'پیغام تصویری' : message.title),
    ),
    backgroundColor: Colors.black,
    body: InteractiveViewer(
      minScale: .75,
      maxScale: 4,
      child: Center(
        child: Hero(
          tag: 'image-message-${message.id}',
          child: Image.network(
            message.url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),
      ),
    ),
  );
}
