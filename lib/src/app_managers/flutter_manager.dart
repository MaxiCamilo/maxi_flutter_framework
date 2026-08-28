import 'dart:ui' show AppLifecycleState;

import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_framework/maxi_framework.dart';

FlutterManager get flutterAppManager =>
    appManager.dynamicCastResult<FlutterManager>(errorMessage: const FixedOration(message: 'The application manager is not a FlutterManager, so it is not possible to access the FlutterStatusObserver')).content;

abstract interface class FlutterManager {
  FlutterStatusObserver get statusObserver;
  bool get isService;
}

extension FlutterManagerExtension on FlutterManager {
  Stream<void> get onInterfaceDetached => statusObserver.appLifecycleStateChanged.where((state) => state == AppLifecycleState.detached);
}
