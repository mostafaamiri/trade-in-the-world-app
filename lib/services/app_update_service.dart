import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef UpdateProgressCallback = void Function(
  int receivedBytes,
  int? totalBytes,
);

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const _channel = MethodChannel('trade_around_the_world/app_update');

  final http.Client _client;

  Future<void> downloadAndInstall({
    required Uri metadataUrl,
    required UpdateProgressCallback onProgress,
  }) async {
    File? apkFile;
    var keepDownloadedFile = false;
    try {
      if (!Platform.isAndroid) {
        throw const AppUpdateException(
          'نصب مستقیم بروزرسانی فقط در اندروید در دسترس است.',
        );
      }

      final metadataResponse = await _client.get(metadataUrl);
      if (metadataResponse.statusCode < 200 ||
          metadataResponse.statusCode >= 300) {
        throw const AppUpdateException('دریافت اطلاعات بروزرسانی ناموفق بود.');
      }
      final metadata = jsonDecode(metadataResponse.body);
      if (metadata is! Map) {
        throw const AppUpdateException('اطلاعات بروزرسانی نامعتبر است.');
      }
      final apkUrl = Uri.tryParse('${metadata['apkUrl'] ?? ''}');
      if (apkUrl == null ||
          !apkUrl.hasScheme ||
          (apkUrl.scheme != 'https' && apkUrl.scheme != 'http')) {
        throw const AppUpdateException('لینک فایل بروزرسانی نامعتبر است.');
      }

      final response = await _client.send(http.Request('GET', apkUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AppUpdateException('دانلود فایل بروزرسانی ناموفق بود.');
      }

      final directory = await getTemporaryDirectory();
      apkFile = File(
        '${directory.path}${Platform.pathSeparator}trade-in-the-world-update.apk',
      );
      if (await apkFile.exists()) await apkFile.delete();
      final output = apkFile.openWrite();
      var receivedBytes = 0;
      final totalBytes = response.contentLength;
      onProgress(0, totalBytes);
      try {
        await for (final chunk in response.stream) {
          output.add(chunk);
          receivedBytes += chunk.length;
          onProgress(receivedBytes, totalBytes);
        }
      } finally {
        await output.close();
      }

      if (receivedBytes == 0 || !await apkFile.exists()) {
        throw const AppUpdateException('فایل بروزرسانی خالی است.');
      }
      try {
        await _channel.invokeMethod<void>('installApk', {'path': apkFile.path});
      } on PlatformException catch (error) {
        throw AppUpdateException(
          error.message ?? 'باز کردن نصب کننده اندروید ممکن نشد.',
        );
      }
      keepDownloadedFile = true;
    } finally {
      if (!keepDownloadedFile && apkFile != null && await apkFile.exists()) {
        await apkFile.delete();
      }
    }
  }

  void dispose() => _client.close();
}
