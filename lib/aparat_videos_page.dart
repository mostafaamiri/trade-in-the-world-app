import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

class AparatVideosPage extends StatefulWidget {
  const AparatVideosPage({super.key, required this.api});

  final GameApi api;

  @override
  State<AparatVideosPage> createState() => _AparatVideosPageState();
}

class _AparatVideosPageState extends State<AparatVideosPage> {
  late Future<List<AparatVideo>> _videos;

  @override
  void initState() {
    super.initState();
    _videos = widget.api.aparatVideos();
  }

  void _refresh() {
    setState(() => _videos = widget.api.aparatVideos());
  }

  Future<void> _openVideo(AparatVideo video) async {
    final uri = Uri.tryParse(video.url);
    if (uri == null || uri.scheme != 'https') {
      if (mounted) await showFailure(context, 'نشانی ویدیو معتبر نیست.');
      return;
    }
    try {
      final openedInApp = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!openedInApp &&
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const GameApiException('باز کردن ویدیوی آپارات ممکن نشد.');
      }
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ویدیوهای ما در آپارات'),
      actions: [
        IconButton(
          tooltip: 'بروزرسانی فهرست',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ScreenBackground(
      child: FutureBuilder<List<AparatVideo>>(
        future: _videos,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش دوباره'),
              ),
            );
          }
          final videos = snapshot.data ?? const <AparatVideo>[];
          if (videos.isEmpty) {
            return const Center(
              child: Text('هنوز ویدیویی در آپارات ثبت نشده است.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final video = videos[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffe53935),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.play_arrow_rounded),
                  ),
                  title: Text(
                    video.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: video.note.isEmpty
                      ? const Text('مشاهده در آپارات')
                      : Text(video.note),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openVideo(video),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
