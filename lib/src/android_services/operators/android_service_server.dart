import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/maxi_flutter_framework.dart';
import 'package:maxi_flutter_framework/src/android_services/channels/android_service_server_data_channel.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceServer with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub implements AndroidServiceInterface {
  final dynamic Function(ServiceInstance) onForeground;
  final FutureOr<bool> Function(ServiceInstance) onIosBackground;
  final bool autoStart;
  final bool isForegroundMode;
  final bool autoStartOnBoot;

  late FlutterBackgroundService _service;

  @override
  bool get isServer => true;

  AndroidServiceServer({
    required this.onForeground,
    required this.onIosBackground,

    this.isForegroundMode = true,
    this.autoStartOnBoot = false,
    this.autoStart = false,
  });

  @override
  Future<Result<void>> performInitialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    _service = FlutterBackgroundService();
    final configurationResult = tryFunction(
      const FixedOration(message: 'Configuring Android service'),

      () => _service.configure(
        iosConfiguration: IosConfiguration(autoStart: autoStart, onForeground: onForeground, onBackground: onIosBackground),
        androidConfiguration: AndroidConfiguration(
          autoStart: autoStart,
          onStart: onForeground,
          isForegroundMode: isForegroundMode,
          autoStartOnBoot: autoStartOnBoot,
        ),
      ),
    );

    if (configurationResult.itsFailure) {
      return configurationResult.cast();
    }

    final startResult = await volatileFuture<bool>(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'Failed to start Android service'),
      ),
      function: () => _service.startService(),
    );

    if (startResult.itsFailure) {
      return startResult.cast();
    }

    if (!startResult.content) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service could not be mounted'),
      );
    }

    final activityCheckResult = await _checkActivity();
    if (activityCheckResult.itsFailure) {
      return activityCheckResult.cast();
    }

    lifecycleScope.joinStream(
      stream: _service.on('turningOff'),
      onData: (event) => dispose(),
      onDone: () => dispose(),
    );

    lifecycleScope.joinStream(
      stream: flutterAppManager.statusObserver.appLifecycleStateChanged,
      onData: (event) => _service.invoke('appLifecycleStateChanged', {'state': event.index}),
    );

    lifecycleScope.joinStream(
      stream: _service.on('client.check'),
      onData: (event) => _service.invoke('client.check.ok'),
    );

    final currentStateResult = await flutterAppManager.statusObserver.getCurrentAppLifecycleState();
    if (currentStateResult.itsFailure) {
      return currentStateResult.cast();
    }

    _service.invoke('appLifecycleStateChanged', {'state': currentStateResult.content.index});

    return voidResult;
  }

  @override
  FutureResult<void> startPing() => initialize().onCorrectFutureSelect((_) => _checkActivity());

  FutureResult<void> _checkActivity() async {
    final completer = Completer<bool>();
    final sub = lifecycleScope.joinStream(
      stream: _service.on('client.echo'),
      onData: (event) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onDone: () => completer.completeError(
        NegativeResult.controller(
          code: ErrorCode.invalidFunctionality,
          message: const FixedOration(message: 'Activity check failed, service is turning off'),
        ),
      ),
    );

    for (int i = 0; i < 150; i++) {
      final wait = completer.future.timeout(const Duration(milliseconds: 50), onTimeout: () => false);
      _service.invoke('service.echo');
      if (await wait) {
        sub.cancel();
        return voidResult;
      }
    }

    sub.cancel();
    return NegativeResult.controller(
      code: ErrorCode.invalidFunctionality,
      message: const FixedOration(message: 'Activity check failed, service did not respond in time'),
    );
  }

  @override
  Stream<AppLifecycleState> get appLifecycleStateChanged => flutterAppManager.statusObserver.appLifecycleStateChanged;

  @override
  FutureResult<Channel<Map<String, dynamic>, Map<String, dynamic>>> buildChannel(String name) async {
    final initResult = await initialize();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    return ResultValue(
      content: lifecycleScope.joinDisposableObject(AndroidServiceServerDataChannel(name: name, service: _service)),
    );
  }

  @override
  FutureResult<bool> checkIsServiceRunning() async {
    if (!isInitialized || itWasDiscarded) {
      return ResultValue(content: false);
    }

    return volatileFuture(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'Failed to check if Android service is running'),
      ),
      function: () => _service.isRunning(),
    );
  }

  @override
  FutureResult<void> closeService() async {
    if (!isInitialized || itWasDiscarded) {
      return voidResult;
    }

    return sendRequest(name: 'shutdown');
  }

  @override
  FutureResult<AppLifecycleState> getCurrentAppLifecycleState() {
    return flutterAppManager.statusObserver.getCurrentAppLifecycleState();
  }
}
