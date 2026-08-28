import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/src/android_services/channels/android_service_client_data_channel.dart';
import 'package:maxi_flutter_framework/src/android_services/operators/android_service_interface.dart';
import 'package:maxi_flutter_framework/src/app_managers/flutter_service_manager.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:maxi_thread/maxi_thread.dart';

class AndroidServiceClient with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub implements AndroidServiceInterface {
  @override
  bool get isServer => false;

  final ServiceInstance serviceInstance;

  late StreamController<AppLifecycleState> _appLifecycleStateController;
  late AppLifecycleState _currentAppLifecycleState;

  AndroidServiceClient({required this.serviceInstance});

  @override
  Stream<AppLifecycleState> get appLifecycleStateChanged => _appLifecycleStateController.stream;

  @override
  FutureResult<Channel<Map<String, dynamic>, Map<String, dynamic>>> buildChannel(String name) async {
    final initResult = await initialize();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    return ResultValue(
      content: lifecycleScope.joinDisposableObject(AndroidServiceClientDataChannel(name: name, service: serviceInstance)),
    );
  }

  @override
  FutureResult<bool> checkIsServiceRunning() async => ResultValue(content: true);

  @override
  FutureResult<AppLifecycleState> getCurrentAppLifecycleState() async {
    return ResultValue(content: _currentAppLifecycleState);
  }

  @override
  Future<Result<void>> performInitialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    _currentAppLifecycleState = AppLifecycleState.resumed;
    _appLifecycleStateController = lifecycleScope.joinStreamController(StreamController<AppLifecycleState>.broadcast());

    lifecycleScope.joinStream(
      stream: serviceInstance.on('service.echo'),
      onData: (_) => serviceInstance.invoke('client.echo'),
    );

    lifecycleScope.joinStream(
      stream: serviceInstance.on('appLifecycleStateChanged'),
      onData: (data) {
        final numResult = tryFunction(const FixedOration(message: 'Failed to parse app lifecycle state'), () {
          final number = data!['state'] as int;
          return AppLifecycleState.values.elementAt(number);
        });
        if (numResult.itsCorrect) {
          final enumResult = numResult.content;
          _currentAppLifecycleState = enumResult;
          _appLifecycleStateController.add(enumResult);
        } else {
          log('Failed to parse app lifecycle state: ${numResult.error}');
        }
      },
    );

    defineAppManager(FlutterServiceManager(serviceClient: this));
    final initResult = await initAppManager();
    if (initResult.itsFailure) return initResult.cast();

    return voidResult;
  }

  @override
  FutureResult<void> closeService() async {
    dispose();

    return voidResult;
  }

  @override
  void performInitializedObjectDiscard() {
    super.performInitializedObjectDiscard();
    try {
      serviceInstance.invoke('turningOff');
    } catch (e) {
      log('Failed to invoke turningOff: $e');
    }

    threadSystem.dispose();
    Future.delayed(const Duration(milliseconds: 50)).whenComplete(() {
      serviceInstance.stopSelf();
    });
  }

  @override
  FutureResult<void> startPing() async {
    final completer = Completer<bool>();
    final sub = lifecycleScope.joinStream(
      stream: serviceInstance.on('client.check.ok'),
      onData: (event) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onDone: () => completer.completeError(
        NegativeResult.controller(
          code: ErrorCode.invalidFunctionality,
          message: const FixedOration(message: 'Ping check failed, service is turning off'),
        ),
      ),
    );

    for (int i = 0; i < 150; i++) {
      final wait = completer.future.timeout(const Duration(milliseconds: 50), onTimeout: () => false);
      serviceInstance.invoke('client.check');
      if (await wait) {
        sub.cancel();
        return voidResult;
      }
    }

    sub.cancel();
    return NegativeResult.controller(
      code: ErrorCode.invalidFunctionality,
      message: const FixedOration(message: 'Ping check failed, service did not respond in time'),
    );
  }
}
