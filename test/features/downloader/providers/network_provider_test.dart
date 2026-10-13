import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ytdlp/features/downloader/core/app_router.dart';
import 'package:flutter_ytdlp/features/downloader/providers/network_provider.dart';
import 'package:flutter_ytdlp/features/downloader/services/network_service.dart';

void main() {
  test('provider containers own independent network services', () async {
    final firstContainer = ProviderContainer();
    final firstService = firstContainer.read(networkServiceProvider);

    firstContainer.dispose();
    await Future<void>.delayed(Duration.zero);

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    final secondService = secondContainer.read(networkServiceProvider);

    expect(secondService, isNot(same(firstService)));
  });

  test(
    'a fresh service still emits after an older service is disposed',
    () async {
      final firstChanges = StreamController<List<ConnectivityResult>>();
      final firstService = NetworkService(
        connectivityChanges: () => firstChanges.stream,
      );
      firstService.init();
      await firstService.dispose();
      await firstChanges.close();

      final secondChanges = StreamController<List<ConnectivityResult>>();
      final secondService = NetworkService(
        connectivityChanges: () => secondChanges.stream,
      );
      addTearDown(() async {
        await secondService.dispose();
        await secondChanges.close();
      });

      final nextStatus = secondService.statusStream.first;
      secondService.init();
      secondChanges.add(const [ConnectivityResult.wifi]);

      expect(await nextStatus, NetworkStatus.online);
    },
  );

  test('downloader routes preserve their route names', () {
    for (final routeName in [
      AppRoutes.analyze,
      AppRoutes.download,
      AppRoutes.summary,
    ]) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: routeName));
      expect(route.settings.name, routeName);
    }
  });
}
