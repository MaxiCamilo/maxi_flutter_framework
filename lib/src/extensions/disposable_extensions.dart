import 'package:flutter/widgets.dart';
import 'package:maxi_dart_framework/maxi_dart_framework.dart';

class _FlutterAutoDispose extends WidgetsBindingObserver {
  final Disposable disposable;

  _FlutterAutoDispose(this.disposable) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      disposable.dispose();
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}

extension DisposableExtensions on Disposable {
  void attachFlutterAutoDispose() {
    _FlutterAutoDispose(this);
  }
}
