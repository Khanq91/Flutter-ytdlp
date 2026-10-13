import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ytdlp/features/downloader/models/download_task.dart';
import 'package:flutter_ytdlp/features/downloader/models/format_option.dart';
import 'package:flutter_ytdlp/features/downloader/models/playlist_entry.dart';
import 'package:flutter_ytdlp/features/downloader/models/video_info.dart';
import 'package:flutter_ytdlp/features/downloader/providers/download_provider.dart';
import 'package:flutter_ytdlp/features/downloader/services/download_permission_service.dart';
import 'package:flutter_ytdlp/features/downloader/services/downloader_storage_service.dart';
import 'package:flutter_ytdlp/features/downloader/services/ytdlp_service.dart';

void main() {
  test('rapid sequential enqueue starts each task exactly once', () async {
    final gateway = _RecordingDownloadGateway();
    final container = await _readyContainer(gateway);
    addTearDown(gateway.dispose);

    final notifier = container.read(downloadProvider.notifier);
    await notifier.enqueue(info: _video('one'), format: _format);
    await notifier.enqueue(info: _video('two'), format: _format);

    expect(gateway.startedTaskIds, hasLength(1));

    await gateway.complete(gateway.startedTaskIds.single);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.startedTaskIds, hasLength(2));
    expect(gateway.startedTaskIds.toSet(), hasLength(2));
    expect(container.read(downloadProvider).activeTasks, hasLength(1));
    expect(container.read(downloadProvider).queuedTasks, isEmpty);
  });

  test('changing the output directory applies to the next dispatch', () async {
    final gateway = _RecordingDownloadGateway();
    final container = await _readyContainer(gateway);
    addTearDown(gateway.dispose);

    final notifier = container.read(downloadProvider.notifier);
    await notifier.enqueue(info: _video('one'), format: _format);
    expect(gateway.outputDirs, ['/downloads']);

    await container
        .read(downloadOutputDirectoryProvider.notifier)
        .setPath('/music');
    await gateway.complete(gateway.startedTaskIds.single);
    await Future<void>.delayed(Duration.zero);
    await notifier.enqueue(info: _video('two'), format: _format);

    expect(gateway.outputDirs, ['/downloads', '/music']);
  });

  test('synchronous start failure moves the task to error', () async {
    final gateway = _ThrowingDownloadGateway();
    final container = await _readyContainer(gateway);

    await container
        .read(downloadProvider.notifier)
        .enqueue(info: _video('one'), format: _format);

    final task = container.read(downloadProvider).tasks.single;
    expect(task.status, DownloadStatus.error);
    expect(task.errorMessage, contains('start failed'));
  });

  test('dispatch limit override serializes the fake gateway', () async {
    final gateway = _RecordingDownloadGateway();
    final container = await _readyContainer(gateway);
    addTearDown(gateway.dispose);

    await container
        .read(downloadProvider.notifier)
        .enqueueBatch(infos: [_video('one'), _video('two')], format: _format);

    expect(gateway.startedTaskIds, hasLength(1));
    expect(container.read(downloadProvider).activeTasks, hasLength(1));
    expect(container.read(downloadProvider).queuedTasks, hasLength(1));

    await gateway.complete(gateway.startedTaskIds.single);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.startedTaskIds, hasLength(2));
    expect(gateway.startedTaskIds.toSet(), hasLength(2));
    expect(container.read(downloadProvider).activeTasks, hasLength(1));
    expect(container.read(downloadProvider).queuedTasks, isEmpty);
  });

  test(
    'cancel waits for native acknowledgement before advancing queue',
    () async {
      final gateway = _RecordingDownloadGateway();
      final container = await _readyContainer(gateway);
      addTearDown(gateway.dispose);

      await container
          .read(downloadProvider.notifier)
          .enqueueBatch(infos: [_video('one'), _video('two')], format: _format);

      final firstTaskId = gateway.startedTaskIds.single;
      final cancelFuture = container
          .read(downloadProvider.notifier)
          .cancel(firstTaskId);

      expect(gateway.cancelledTaskIds, [firstTaskId]);
      expect(
        container.read(downloadProvider).tasks.first.status,
        DownloadStatus.preparing,
      );
      expect(gateway.startedTaskIds, hasLength(1));

      await gateway.acknowledgeCancel(firstTaskId);
      await cancelFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(downloadProvider).tasks.first.status,
        DownloadStatus.cancelled,
      );
      expect(gateway.startedTaskIds, hasLength(2));
    },
  );

  test('failed native cancel keeps task active and queue blocked', () async {
    final gateway = _RecordingDownloadGateway();
    final container = await _readyContainer(gateway);
    addTearDown(gateway.dispose);

    await container
        .read(downloadProvider.notifier)
        .enqueueBatch(infos: [_video('one'), _video('two')], format: _format);

    final firstTaskId = gateway.startedTaskIds.single;
    final cancelFuture = container
        .read(downloadProvider.notifier)
        .cancel(firstTaskId);
    gateway.rejectCancel(firstTaskId);

    expect(await cancelFuture, isFalse);
    expect(
      container.read(downloadProvider).tasks.first.status,
      DownloadStatus.preparing,
    );
    expect(container.read(downloadProvider).queuedTasks, hasLength(1));
    expect(gateway.startedTaskIds, hasLength(1));
  });

  test('restores completed tasks from the foreground service', () async {
    final restoredTask = DownloadTask(
      id: 'restored',
      title: 'Restored download',
      url: 'https://example.com/restored',
      formatId: _format.formatId,
      ext: _format.ext,
      status: DownloadStatus.done,
      progress: 1,
      completedAt: DateTime(2026),
    );
    final gateway = _RestoringDownloadGateway([restoredTask]);
    final container = await _readyContainer(gateway);
    addTearDown(gateway.dispose);

    container.read(downloadProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(downloadProvider).tasks, [restoredTask]);
    expect(gateway.startedTaskIds, isEmpty);
  });

  group('startFromFormat', () {
    test('single video: saves the picked folder, asks permission, enqueues', () async {
      final gateway = _RecordingDownloadGateway();
      final permissions = _FakePermissions(granted: true);
      final container = await _readyContainer(gateway, permissions: permissions);
      addTearDown(gateway.dispose);

      final outcome = await container
          .read(downloadProvider.notifier)
          .startFromFormat(
            info: _video('one'),
            format: _format,
            outputPath: '/music',
          );

      expect(outcome, DownloadStartOutcome.started);
      expect(permissions.requests, 1);
      expect(container.read(downloadOutputDirectoryProvider).value, '/music');
      expect(gateway.outputDirs, ['/music']);
      expect(gateway.startedTaskIds, hasLength(1));
      expect(
        container.read(downloadProvider).tasks.single.url,
        _video('one').url,
      );
    });

    test('picked playlist entries become one task each', () async {
      final gateway = _RecordingDownloadGateway();
      final container = await _readyContainer(
        gateway,
        permissions: _FakePermissions(granted: true),
        dispatchLimit: 8,
      );
      addTearDown(gateway.dispose);

      await container
          .read(downloadProvider.notifier)
          .startFromFormat(
            info: _playlist,
            format: _format,
            selectedEntries: [_entry('a'), _entry('b')],
          );

      final tasks = container.read(downloadProvider).tasks;
      expect(tasks.map((t) => t.url), [
        'https://example.com/a',
        'https://example.com/b',
      ]);
      expect(tasks.map((t) => t.title), ['Entry a', 'Entry b']);
      expect(gateway.startedTaskIds, hasLength(2));
    });

    test('playlist without picked entries is one playlist task', () async {
      final gateway = _RecordingDownloadGateway();
      final container = await _readyContainer(
        gateway,
        permissions: _FakePermissions(granted: true),
      );
      addTearDown(gateway.dispose);

      await container
          .read(downloadProvider.notifier)
          .startFromFormat(info: _playlist, format: _format);

      final task = container.read(downloadProvider).tasks.single;
      expect(task.url, _playlist.url);
      expect(task.title, 'My playlist (2 video)');
      expect(gateway.startedTaskIds, [task.id]);
    });

    test('refused notification permission still enqueues', () async {
      final gateway = _RecordingDownloadGateway();
      final container = await _readyContainer(
        gateway,
        permissions: _FakePermissions(granted: false),
      );
      addTearDown(gateway.dispose);

      final outcome = await container
          .read(downloadProvider.notifier)
          .startFromFormat(info: _video('one'), format: _format);

      expect(outcome, DownloadStartOutcome.startedWithoutNotification);
      expect(gateway.startedTaskIds, hasLength(1));
      // No folder was picked, so the saved one is untouched.
      expect(gateway.outputDirs, ['/downloads']);
    });
  });

  group('downloadTaskProvider', () {
    test('follows its own task only and is released when unwatched', () async {
      final gateway = _RecordingDownloadGateway();
      final container = await _readyContainer(gateway, dispatchLimit: 8);
      addTearDown(gateway.dispose);

      final notifier = container.read(downloadProvider.notifier);
      await notifier.enqueueBatch(
        infos: [_video('one'), _video('two')],
        format: _format,
      );
      final [first, second] = container.read(downloadProvider).tasks;

      var notifications = 0;
      final sub = container.listen(
        downloadTaskProvider(first.id),
        (_, __) => notifications++,
      );
      expect(sub.read(), first);

      // Another task's progress must not wake this one.
      gateway.progress(second.id, 0.5);
      await container.pump();
      expect(notifications, 0);

      // Same id, new instance (DownloadTask.== is id-based) must notify.
      gateway.progress(first.id, 0.5);
      await container.pump();
      expect(notifications, 1);
      expect(sub.read()!.progress, 0.5);

      await gateway.complete(first.id);
      await container.pump();
      notifier.remove(first.id);
      await container.pump();
      expect(sub.read(), isNull);

      sub.close();
      await container.pump();
      expect(
        container.getAllProviderElements().map((e) => e.provider),
        isNot(contains(downloadTaskProvider(first.id))),
      );
    });
  });

  group('output directory', () {
    test('loads through the storage gateway and persists picks', () async {
      final storage = _FakeStorage(path: '/saved');
      final container = ProviderContainer(
        overrides: [downloadStorageGatewayProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(downloadOutputDirectoryProvider.future),
        '/saved',
      );
      expect(storage.initCalls, 1);
      expect(storage.permissionRequests, 1);

      final notifier = container.read(downloadOutputDirectoryProvider.notifier);
      await notifier.setPath('/music');
      expect(storage.savedPaths, ['/music']);
      expect(container.read(downloadOutputDirectoryProvider).value, '/music');

      storage.nextPick = '/pending';
      expect(await notifier.pickDirectory(save: false), '/pending');
      expect(storage.savedPaths, ['/music']);
      expect(container.read(downloadOutputDirectoryProvider).value, '/music');

      storage.nextPick = '/picked';
      expect(await notifier.pickDirectory(), '/picked');
      expect(storage.savedPaths, ['/music', '/picked']);
      expect(container.read(downloadOutputDirectoryProvider).value, '/picked');

      storage.nextPick = null;
      expect(await notifier.pickDirectory(), isNull);
      expect(storage.savedPaths, ['/music', '/picked']);
    });

    test('tasks enqueued before the folder is known start once it is', () async {
      final gateway = _RecordingDownloadGateway();
      final storage = _FakeStorage(path: '/saved', initGate: Completer<void>());
      final container = ProviderContainer(
        overrides: [
          downloadGatewayProvider.overrideWithValue(gateway),
          downloadStorageGatewayProvider.overrideWithValue(storage),
          downloadDispatchLimitProvider.overrideWithValue(1),
        ],
      );
      addTearDown(() {
        container.dispose();
        gateway.dispose();
      });

      await container
          .read(downloadProvider.notifier)
          .enqueue(info: _video('one'), format: _format);
      expect(container.read(downloadProvider).queuedTasks, hasLength(1));
      expect(gateway.startedTaskIds, isEmpty);

      storage.initGate!.complete();
      await container.read(downloadOutputDirectoryProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.startedTaskIds, hasLength(1));
      expect(gateway.outputDirs, ['/saved']);
      expect(container.read(downloadProvider).activeTasks, hasLength(1));
    });

    test('storage init failure lands on the task, no fallback folder', () async {
      final gateway = _RecordingDownloadGateway();
      final storage = _FakeStorage(path: '/saved', initError: 'no storage');
      final container = ProviderContainer(
        overrides: [
          downloadGatewayProvider.overrideWithValue(gateway),
          downloadStorageGatewayProvider.overrideWithValue(storage),
          downloadDispatchLimitProvider.overrideWithValue(1),
        ],
      );
      addTearDown(() {
        container.dispose();
        gateway.dispose();
      });

      await expectLater(
        container.read(downloadOutputDirectoryProvider.future),
        throwsA(isA<StateError>()),
      );
      await container
          .read(downloadProvider.notifier)
          .enqueue(info: _video('one'), format: _format);

      final task = container.read(downloadProvider).tasks.single;
      expect(task.status, DownloadStatus.error);
      expect(task.errorMessage, contains('no storage'));
      expect(gateway.startedTaskIds, isEmpty);
    });
  });
}

/// Container whose output directory has already resolved, so enqueue
/// dispatches synchronously like it does once the analyze screen is ready.
Future<ProviderContainer> _readyContainer(
  DownloadGateway gateway, {
  DownloadPermissionGateway? permissions,
  int dispatchLimit = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      downloadGatewayProvider.overrideWithValue(gateway),
      downloadOutputDirectoryProvider.overrideWith(_FixedOutputDirectory.new),
      downloadDispatchLimitProvider.overrideWithValue(dispatchLimit),
      if (permissions != null)
        downloadPermissionGatewayProvider.overrideWithValue(permissions),
    ],
  );
  addTearDown(container.dispose);
  await container.read(downloadOutputDirectoryProvider.future);
  return container;
}

final _playlist = VideoInfo(
  id: 'pl',
  title: 'My playlist',
  url: 'https://example.com/playlist',
  platform: VideoPlatform.youtube,
  type: VideoType.playlist,
  playlistCount: 2,
  skippedCount: null,
  formats: const [],
);

PlaylistEntry _entry(String id) =>
    PlaylistEntry(id: id, title: 'Entry $id', url: 'https://example.com/$id');

class _FakePermissions implements DownloadPermissionGateway {
  _FakePermissions({required this.granted});

  final bool granted;
  int requests = 0;

  @override
  Future<bool> requestNotificationPermission() async {
    requests++;
    return granted;
  }
}

class _FakeStorage implements DownloadStorageGateway {
  _FakeStorage({required String path, this.initGate, this.initError})
    : _path = path;

  String _path;

  /// When set, [init] stays pending until this completes.
  final Completer<void>? initGate;
  final String? initError;
  int initCalls = 0;
  int permissionRequests = 0;
  final List<String> savedPaths = [];
  String? nextPick;

  @override
  Future<void> init() async {
    initCalls++;
    if (initError != null) throw StateError(initError!);
    await initGate?.future;
  }

  @override
  String get downloadPath => _path;

  @override
  Future<bool> requestStoragePermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<String> getExternalBasePath() async => '/storage/emulated/0';

  @override
  Future<void> setAndSavePath(String path) async {
    _path = path;
    savedPaths.add(path);
  }

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async => nextPick;

  @override
  Future<void> openDownloadFolder() async {}
}

const _format = FormatOption(
  formatId: 'audio',
  ext: 'm4a',
  quality: 'Audio',
  isAudioOnly: true,
);

VideoInfo _video(String id) => VideoInfo(
  id: id,
  title: 'Video $id',
  url: 'https://example.com/$id',
  platform: VideoPlatform.youtube,
  type: VideoType.video,
  skippedCount: null,
  formats: const [],
);

/// Publishes a fixed directory without touching disk or SharedPreferences.
class _FixedOutputDirectory extends OutputDirectoryNotifier {
  @override
  Future<String> build() async => '/downloads';

  @override
  Future<void> setPath(String path) async => state = AsyncData(path);
}

class _RecordingDownloadGateway implements DownloadGateway {
  final List<String> startedTaskIds = [];
  final List<String?> outputDirs = [];
  final List<String> cancelledTaskIds = [];
  final List<StreamController<DownloadTask>> _controllers = [];
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, StreamController<DownloadTask>> _controllersByTask = {};
  final Map<String, Completer<bool>> _cancelCompleters = {};

  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    startedTaskIds.add(task.id);
    outputDirs.add(outputDir);
    final controller = StreamController<DownloadTask>();
    _controllers.add(controller);
    _tasks[task.id] = task;
    _controllersByTask[task.id] = controller;
    return controller.stream;
  }

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async => const ExtractAudioResult(success: true);

  @override
  Future<bool> cancel(String taskId) {
    cancelledTaskIds.add(taskId);
    final completer = Completer<bool>();
    _cancelCompleters[taskId] = completer;
    return completer.future;
  }

  Future<void> acknowledgeCancel(String taskId) async {
    final task = _tasks[taskId]!;
    final controller = _controllersByTask[taskId]!;
    controller.add(task.copyWith(status: DownloadStatus.cancelled));
    await controller.close();
    _cancelCompleters.remove(taskId)!.complete(true);
  }

  void rejectCancel(String taskId) {
    _cancelCompleters.remove(taskId)!.complete(false);
  }

  Future<void> complete(String taskId) async {
    final task = _tasks[taskId]!;
    final controller = _controllersByTask[taskId]!;
    controller.add(task.copyWith(status: DownloadStatus.done, progress: 1));
    await controller.close();
  }

  void progress(String taskId, double value) {
    final task = _tasks[taskId]!;
    _controllersByTask[taskId]!.add(
      task.copyWith(status: DownloadStatus.downloading, progress: value),
    );
  }

  void dispose() {
    for (final controller in _controllers) {
      if (!controller.isClosed) controller.close();
    }
  }
}

class _ThrowingDownloadGateway implements DownloadGateway {
  @override
  Future<bool> cancel(String taskId) async => false;

  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    throw StateError('start failed');
  }

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async => const ExtractAudioResult(success: true);
}

class _RestoringDownloadGateway extends _RecordingDownloadGateway
    implements RestorableDownloadGateway {
  _RestoringDownloadGateway(this.restored);

  final List<DownloadTask> restored;

  @override
  Future<List<DownloadTask>> restoreDownloads() async => restored;
}
