import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/src/android_service/android_service_connector.dart';
import 'package:maxi_flutter_framework/src/android_service/channels/android_service_port_channel.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:maxi_thread/maxi_thread.dart';

class AndroidServicePort with DisposableMixin, LifecycleHub implements FlutterStatusObserver {
  final ServiceInstance serviceInstance;
  String serviceName;

  late final StreamController<AppLifecycleState> appLifecycleStateChangedController;

  @override
  Stream<AppLifecycleState> get appLifecycleStateChanged => appLifecycleStateChangedController.stream;

  Channel<Map<String, dynamic>, Map<String, dynamic>> operator [](String key) {
    return AndroidServicePortChannel(port: this, serviceInstance: serviceInstance, streamName: key);
  }

  AndroidServicePort({required this.serviceInstance, required this.serviceName}) {
    lifecycleScope.joinStream(stream: serviceInstance.on(AndroidServiceConnector.kRequestStopService), onData: (_) => dispose());

    appLifecycleStateChangedController = StreamController<AppLifecycleState>.broadcast();
    lifecycleScope.joinStream(
      stream: serviceInstance.on(AndroidServiceConnector.kAppStatusChanged),
      onData: (data) {
        final state = AppLifecycleState.values.selectItem((e) => e.index == data?['value']);
        if (state != null) {
          appLifecycleStateChangedController.add(state);
        }
      },
    );

    lifecycleScope.joinStream(stream: serviceInstance.on(AndroidServiceConnector.kGetServerName), onData: (_) => serviceInstance.invoke(AndroidServiceConnector.kSetServerName, {'name': serviceName}));
    lifecycleScope.joinStream(
      stream: serviceInstance.on(AndroidServiceConnector.kSetServerName),
      onData: (map) {
        final newName = map?['name'];
        if (newName is String) {
          serviceName = newName;
        }
        serviceInstance.invoke(AndroidServiceConnector.kSetServerName, {'name': serviceName});
      },
    );
  }

  @override
  void performObjectDiscard() {
    volatileFunction(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'Error stopping service'),
      ),
      function: () => serviceInstance.invoke(AndroidServiceConnector.kStopedService),
    ).logIfFails();

    threadSystem.dispose();
    Future.delayed(const Duration(milliseconds: 250)).whenComplete(() {
      serviceInstance.stopSelf();
    });
  }
  
  @override
  FutureResult<AppLifecycleState> getCurrentAppLifecycleState() {
    // TODO: implement getCurrentAppLifecycleState
    throw UnimplementedError();
  }
}
