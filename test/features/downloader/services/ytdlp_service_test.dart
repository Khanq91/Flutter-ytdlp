import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ytdlp/features/downloader/models/download_task.dart';
import 'package:flutter_ytdlp/features/downloader/services/ytdlp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ytdlp_channel');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('download sends task id and maps native cancellation', () async {
    MethodCall? enqueueCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'enqueueDownload') {
            enqueueCall = call;
            return json.encode({'accepted': true});
          }
          if (call.method == 'getDownloadTask') {
            return json.encode(_nativeTask(_task, status: 'cancelled'));
          }
          return null;
        });

    final events =
        await YtdlpService.instance
            .download(_task, outputDir: '/downloads')
            .toList();

    expect(enqueueCall?.arguments, containsPair('taskId', _task.id));
    expect(events.last.status, DownloadStatus.cancelled);
  });

  test('cancel requires both accepted and stopped acknowledgement', () async {
    var stopped = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancelDownload') {
            return json.encode({'accepted': true, 'stopped': stopped});
          }
          return null;
        });

    expect(await YtdlpService.instance.cancel(_task.id), isFalse);

    stopped = true;
    expect(await YtdlpService.instance.cancel(_task.id), isTrue);
  });

  test('concurrent streams receive progress for their own task ids', () async {
    final completedTaskIds = <String>{};
    final progressTaskIds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map<Object?, Object?>?;
          final taskId = arguments?['taskId'] as String?;
          if (call.method == 'enqueueDownload') {
            return json.encode({'accepted': true});
          }
          if (call.method == 'getDownloadTask') {
            return json.encode(
              _nativeTask(
                taskId == _task.id ? _task : _secondTask,
                status:
                    completedTaskIds.contains(taskId) ? 'done' : 'downloading',
                progress: completedTaskIds.contains(taskId) ? 1 : 0,
              ),
            );
          }
          if (call.method == 'getProgress') {
            progressTaskIds.add(taskId!);
            return json.encode({
              'status': 'downloading',
              'percent': taskId == _task.id ? 25 : 75,
              'speed': '1 MB/s',
              'eta': '3s',
            });
          }
          return null;
        });

    final firstEventsFuture =
        YtdlpService.instance.download(_task, outputDir: '/downloads').toList();
    final secondEventsFuture =
        YtdlpService.instance
            .download(_secondTask, outputDir: '/downloads')
            .toList();

    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(progressTaskIds, containsAll({_task.id, _secondTask.id}));

    completedTaskIds.addAll({_task.id, _secondTask.id});
    final firstEvents = await firstEventsFuture;
    final secondEvents = await secondEventsFuture;
    expect(
      firstEvents,
      contains(
        predicate<DownloadTask>((task) {
          return task.id == _task.id && task.progress == 0.25;
        }),
      ),
    );
    expect(
      secondEvents,
      contains(
        predicate<DownloadTask>((task) {
          return task.id == _secondTask.id && task.progress == 0.75;
        }),
      ),
    );
  });

  test('restores persisted foreground task snapshots', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getDownloadTasks') {
            return json.encode([
              _nativeTask(_task, status: 'done', progress: 1),
              _nativeTask(_secondTask, status: 'waitingToRetry'),
            ]);
          }
          return null;
        });

    final restored = await YtdlpService.instance.restoreDownloads();

    expect(restored, hasLength(2));
    expect(restored.first.status, DownloadStatus.done);
    expect(restored.last.status, DownloadStatus.waitingToRetry);
  });
}

Map<String, Object?> _nativeTask(
  DownloadTask task, {
  required String status,
  double progress = 0,
}) => {
  'id': task.id,
  'title': task.title,
  'url': task.url,
  'formatId': task.formatId,
  'ext': task.ext,
  'thumbnail': task.thumbnail,
  'status': status,
  'progress': progress,
  'speed': '',
  'eta': '',
  'errorMessage': null,
  'outputPath': status == 'done' ? '/${task.id}.m4a' : null,
  'startedAt': null,
  'completedAt': null,
};

const _task = DownloadTask(
  id: 'task-1',
  title: 'Video one',
  url: 'https://example.com/one',
  formatId: 'audio',
  ext: 'm4a',
);

const _secondTask = DownloadTask(
  id: 'task-2',
  title: 'Video two',
  url: 'https://example.com/two',
  formatId: 'audio',
  ext: 'm4a',
);
