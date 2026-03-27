import 'package:flutter/widgets.dart';
import 'package:maxi_framework/maxi_framework.dart';

abstract interface class FlutterStatusObserver {
  Stream<AppLifecycleState> get appLifecycleStateChanged;

  FutureResult<AppLifecycleState> getCurrentAppLifecycleState();
}
