import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_flutter_framework/src/android_service/android_service_connection.dart';
import 'package:maxi_flutter_framework/src/android_service/channel/android_service_channel.dart';

class BackgroundAndroidService with DisposableMixin, WithLifecycleScopeMixin, SynchronousInitializationMixin implements AndroidServiceConnection {
  final ServiceInstance service;

  late StreamController<AppLifecycleState> _appLifecycleStateController;

  AppLifecycleState _currentState = AppLifecycleState.resumed;

  new({required this.service});

  @override
  Stream<AppLifecycleState> get lifecycleStateStream async* {
    checkDisposed().$;
    yield* _appLifecycleStateController.stream;
  }

  @override
  Result<void> performInitialization() => resultScopeVoid(() {
    checkDisposed().$;
    service.on('ping').listen((_) => service.invoke('pong'));
    service.on('disconnected').listen((_) {
      dispose();
      service.stopSelf();
    });

    _appLifecycleStateController = heart.attachStreamController(StreamController<AppLifecycleState>.broadcast());
    service.on('lifecycleChanged').listen((x) {
      final value = AppLifecycleState.values.firstWhere((e) => e.toString() == x!['state']);
      _currentState = value;
      _appLifecycleStateController.add(value);
    });
    service.invoke('lifecycleChanged');
  });

  @override
  FutureResult<Channel<Map<String, dynamic>, Map<String, dynamic>>> buildChannel(String name) => futureScopeValue(() async {
    checkDisposed().$;
    initialize().$;

    final newChannel = AndroidServiceChannel(name, service.invoke, service.on);
    heart.attachChild(newChannel);

    return newChannel;
  });

  @override
  Result<void> stopService() => resultScopeVoid(() {
    dispose();
    service.stopSelf();
  });

  @override
  FutureEmptyResult<dynamic> ping({Duration? timeout}) => futureScopeVoid(() async {
    checkDisposed().$;

    final completer = Completer<Result<void>>();
    service
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

    service.invoke('ping');
    await completer.future;
  });

  @override
  FutureResult<AppLifecycleState> obtainLifecycleState() => futureScopeValue(() {
    checkDisposed().$;
    return _currentState;
  });
}
