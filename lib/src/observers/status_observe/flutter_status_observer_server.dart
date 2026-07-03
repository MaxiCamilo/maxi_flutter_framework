import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_framework/maxi_framework.dart';

class FlutterStatusObserverServer with DisposableMixin, InitializableMixin, WidgetsBindingObserver, LifecycleHub implements FlutterStatusObserver {
  late AppLifecycleState _currentState;

  late StreamController<AppLifecycleState> _appLifecycleStateController;

  @override
  Result<void> performInitialization() {
    WidgetsFlutterBinding.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);

    _appLifecycleStateController = lifecycleScope.joinStreamController(StreamController<AppLifecycleState>.broadcast());

    return voidResult;
  }

  @override
  Stream<AppLifecycleState> get appLifecycleStateChanged async* {
    initialize().exceptionIfFails(detail: '[¡¡!!] Failed to initialize FlutterStatusObserverServer');

    yield* _appLifecycleStateController.stream;
  }

  @override
  FutureResult<AppLifecycleState> getCurrentAppLifecycleState() async {
    final initResult = initialize();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    return _currentState.asResultValue();
  }

  @override
  void performObjectDiscard() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _currentState = state;
    _appLifecycleStateController.add(state);
  }
}
