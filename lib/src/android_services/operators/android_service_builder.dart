import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/maxi_flutter_framework.dart';
import 'package:maxi_flutter_framework/src/android_services/operators/android_service_client.dart';
import 'package:maxi_flutter_framework/src/android_services/operators/android_service_server.dart';

mixin AndroidService {
  static AndroidServiceInterface server({
    required dynamic Function(ServiceInstance) onForeground,
    required FutureOr<bool> Function(ServiceInstance) onIosBackground,
    bool isForegroundMode = true,
    bool autoStart = false,

    bool autoStartOnBoot = false,
  }) => AndroidServiceServer(
    onForeground: onForeground,
    onIosBackground: onIosBackground,
    isForegroundMode: isForegroundMode,
    autoStart: autoStart,
    autoStartOnBoot: autoStartOnBoot,
  );

  static AndroidServiceInterface client(ServiceInstance serviceInstance) => AndroidServiceClient(serviceInstance: serviceInstance);
}
