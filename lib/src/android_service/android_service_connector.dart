import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/src/android_service/channels/android_service_connector_channel.dart';
import 'package:maxi_flutter_framework/src/app_managers/flutter_manager.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceConnector with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub {
  final bool autoStart;
  final bool isForegroundMode;
  final bool autoStartOnBoot;
  final dynamic Function(ServiceInstance) onForeground;
  final FutureOr<bool> Function(ServiceInstance) onIosBackground;
  final Oration initialNotificationContent;
  final Oration initialNotificationTitle;
  final String serviceName;

  late FlutterBackgroundService _backgroundService;

  @internal
  static const String kGetServerName = 'mx.getServerName';
  @internal
  static const String kSetServerName = 'mx.setServerName';
  @internal
  static const String kRequestStopService = 'mx.requestStopService';
  @internal
  static const String kStopedService = 'mx.stopedService';
  @internal
  static const String kAppStatusChanged = 'mx.appStatusChanged';
  @internal
  static const String kGetAppStatus = 'mx.getAppStatus';

  AndroidServiceConnector({
    required this.autoStart,
    required this.isForegroundMode,
    required this.autoStartOnBoot,
    required this.onForeground,
    required this.onIosBackground,
    required this.serviceName,
    this.initialNotificationContent = emptyOration,
    this.initialNotificationTitle = emptyOration,
  });

  Channel<Map<String, dynamic>, Map<String, dynamic>> operator [](String key) {
    return AndroidServiceConnectorChannel(serviceConnector: this, backgroundServiceProvider: () => _backgroundService, streamName: key);
  }

  @override
  Future<Result<void>> performInitialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    _backgroundService = FlutterBackgroundService();

    final configurationResult = await _backgroundService
        .configure(
          iosConfiguration: IosConfiguration(autoStart: autoStart, onForeground: onForeground, onBackground: onIosBackground),
          androidConfiguration: AndroidConfiguration(
            autoStart: autoStart,
            onStart: onForeground,
            isForegroundMode: isForegroundMode,
            autoStartOnBoot: autoStartOnBoot,
            initialNotificationContent: initialNotificationContent.toString(),
            initialNotificationTitle: initialNotificationTitle.toString(),
          ),
        )
        .toFutureResult(errorMessage: const FixedOration(message: 'Failed to configure background service'));
    if (configurationResult.itsFailure) {
      return configurationResult.cast();
    }

    final initResult = await _backgroundService.startService().toFutureResult(errorMessage: const FixedOration(message: 'Failed to start background service')).breakIfCanceled();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    if (!initResult.content) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'Background service failed to start'),
      );
    }

    lifecycleScope.joinStream(stream: _backgroundService.on(kGetServerName), onData: (event) => _backgroundService.invoke(kSetServerName, {'name': serviceName}));
    lifecycleScope.joinStream(stream: _backgroundService.on(kStopedService), onData: (event) => dispose());

    final stateResult = appManager.dynamicCastResult<FlutterManager>().onCorrectSelect((x) => x.statusObserver.appLifecycleStateChanged);
    if (stateResult.itsFailure) {
      return stateResult.cast();
    }

    lifecycleScope.joinStream(stream: stateResult.content, onData: (state) => _backgroundService.invoke(kAppStatusChanged, {'value': state.index}));
    lifecycleScope.joinStream(
      stream: _backgroundService.on(kGetAppStatus),
      onData: (event) async {
        final value = await appManager.dynamicCastResult<FlutterManager>().onCorrectFuture((x) => x.statusObserver.getCurrentAppLifecycleState()).waitContentOrThrow();

        _backgroundService.invoke(kAppStatusChanged, {'value': value.index});
      },
    );

    return voidResult;
  }

  FutureResult<bool> checkIfServiceIsSameName() async {
    final initResult = await initialize().checkCancelation();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    _backgroundService.invoke(kGetServerName);

    final nameResult = await _backgroundService.on(kSetServerName).waitItem(timeout: const Duration(seconds: 5));
    if (nameResult.itsFailure) {
      return nameResult.cast();
    }

    return (nameResult.content!['name'] == serviceName).asResultValue();
  }

  FutureResult<void> stopService() async {
    final initResult = await initialize().checkCancelation();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    _backgroundService.invoke(kRequestStopService);
    return await onDispose.toFuture().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        return NegativeResult.controller(
          code: ErrorCode.timeout,
          message: const FixedOration(message: 'Timed out while waiting for the service to stop'),
        );
      },
    );
  }

  @override
  void performInitializedObjectDiscard() {}
}
