import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_flutter_framework/src/android_service/android_service_connection.dart';
import 'package:maxi_flutter_framework/src/android_service/channel/android_service_channel.dart';

class MainAndroidService with DisposableMixin, WithLifecycleScopeMixin, AsynchronousInitializationMixin, WidgetsBindingObserver implements AndroidServiceConnection {
  final dynamic Function(ServiceInstance) onForeground;
  final FutureOr<bool> Function(ServiceInstance) onIosBackground;
  final bool isForegroundMode;
  final bool autoStart;
  final bool autoStartOnBoot;

  late final FlutterBackgroundService _service;
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  late final StreamController<AppLifecycleState> _appLifecycleStateController;

  bool _isDisconnected = false;

  new({
    required this.onForeground,
    required this.onIosBackground,
    this.isForegroundMode = true,
    this.autoStart = false,
    this.autoStartOnBoot = false,
  });

  @override
  FutureResult<void> performInitialization() => futureScope<void>(() async {
    checkDisposed().$;
    WidgetsFlutterBinding.ensureInitialized();
    final service = FlutterBackgroundService();

    final isConfigured = (await futureVolatileScope(
      message: Oration('Failed to configure service'),
      function: () => service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onForeground,
          onBackground: onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          autoStart: autoStart,
          onStart: onForeground,
          isForegroundMode: isForegroundMode,
          autoStartOnBoot: autoStartOnBoot,
          foregroundServiceTypes: [AndroidForegroundType.dataSync],
        ),
      ),
    )).$;

    if (!isConfigured) {
      return Result.error('Failed to configure service');
    }

    final success = (await futureVolatileScope(message: Oration('An error occurred while starting the service'), function: () => service.startService())).$;
    if (!success) {
      return Result.error('Failed to start service');
    }

    service.on('ping').listen((_) => service.invoke('pong'), onDone: dispose);
    service.on('lifecycleChanged').listen((_) => _service.invoke('lifecycleChanged', {'state': _currentState.toString()}));
    service.on('disconnected').listen((_) {
      _isDisconnected = true;
      dispose();
    }, onDone: dispose);
    /*
    heart.onDispose(() {
      if (!_isDisconnected) {
        service.invoke('disconnected');
      }
    });*/

    WidgetsBinding.instance.addObserver(this);
    heart.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _appLifecycleStateController = heart.attachStreamController(StreamController<AppLifecycleState>.broadcast());

    _service = service;
    return Result.ok;
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _currentState = state;
    _appLifecycleStateController.add(state);
    _service.invoke('lifecycleChanged', {'state': state.toString()});
  }

  @override
  FutureResult<Channel<Map<String, dynamic>, Map<String, dynamic>>> buildChannel(String name) => futureScopeValue(() async {
    checkDisposed().$;
    await initialize().$;

    final newChannel = AndroidServiceChannel(name, _service.invoke, _service.on);
    heart.attachChild(newChannel);

    return newChannel;
  });

  @override
  Result<void> stopService() {
    if (isDisposed || !isInitialized) {
      return Result.ok;
    }

    if (!_isDisconnected) {
      _service.invoke('disconnected');
      _isDisconnected = true;
      dispose();
    }
    return Result.ok;
  }

  @override
  FutureEmptyResult<dynamic> ping({Duration? timeout}) => futureScopeVoid(() async {
    checkDisposed().$;
    await initialize().$;

    final completer = Completer<Result<void>>();
    _service
        .on('pong')
        .autoclose(timeout ?? const Duration(seconds: 5))
        .first
        .then((_) {
          if (!completer.isCompleted) {
            completer.complete(Result.ok);
          }
        })
        .catchError(
          (error) {
            if (!completer.isCompleted) {
              completer.complete(Result.error(error.toString()));
            }
          },
        );

    _service.invoke('ping');
    await completer.future;
  });

  @override
  Stream<AppLifecycleState> get lifecycleStateStream async* {
    checkDisposed().$;
    await initialize().$;
    yield* _appLifecycleStateController.stream;
  }

  @override
  FutureResult<AppLifecycleState> obtainLifecycleState() => futureScopeValue(() async {
    checkDisposed().$;
    await initialize().$;
    return _currentState;
  });
}
