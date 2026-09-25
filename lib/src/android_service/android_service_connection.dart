import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_flutter_framework/src/android_service/implementations/background_android_service.dart';
import 'package:maxi_flutter_framework/src/android_service/implementations/main_android_service.dart';

abstract interface class AndroidServiceConnection implements WithLifecycleScope, WithLifecycleScopeMixin {
  FutureResult<Channel<Map<String, dynamic>, Map<String, dynamic>>> buildChannel(String name);
  Result<void> stopService();
  FutureEmptyResult ping({Duration? timeout});
  FutureResult<AppLifecycleState> obtainLifecycleState();
  Stream<AppLifecycleState> get lifecycleStateStream;

  static AndroidServiceConnection buildService({
    required dynamic Function(ServiceInstance) onForeground,
    required FutureOr<bool> Function(ServiceInstance) onIosBackground,
    bool isForegroundMode = true,
    bool autoStart = false,
    bool autoStartOnBoot = false,
  }) => MainAndroidService(
    onForeground: onForeground,
    onIosBackground: onIosBackground,
    isForegroundMode: isForegroundMode,
    autoStart: autoStart,
    autoStartOnBoot: autoStartOnBoot,
  );

  static AndroidServiceConnection connectInstance(ServiceInstance service) => BackgroundAndroidService(service: service);
}
