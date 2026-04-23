import 'dart:async';
import 'dart:ui';

import 'package:maxi_flutter_framework/src/app_managers/flutter_manager.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:maxi_thread/maxi_thread.dart';

class FlutterStatusObserverIsolated with DisposableMixin, AsynchronouslyInitializedMixin implements FlutterStatusObserver {
  late StreamController<AppLifecycleState> _appLifecycleStateController;

  @override
  Stream<AppLifecycleState> get appLifecycleStateChanged async* {
    await initialize().waitContentOrThrow();
    yield* _appLifecycleStateController.stream;
  }

  @override
  FutureResult<AppLifecycleState> getCurrentAppLifecycleState() {
    return threadSystem.serverConnection.executeResult(function: _getCurrentAppLifecycleStateOnServer);
  }

  static FutureResult<AppLifecycleState> _getCurrentAppLifecycleStateOnServer(InvocationParameters para) async {
    final appResult = appManager.dynamicCastResult<FlutterManager>(
      errorMessage: const FixedOration(message: 'The application manager is not a FlutterManager, so it is not possible to get the current app lifecycle state'),
    );
    if (appResult.itsFailure) {
      return appResult.cast();
    }

    return appResult.content.statusObserver.getCurrentAppLifecycleState();
  }

  @override
  FutureResult<void> performInitialize() async {
    final channelResult = await threadSystem.serverConnection.buildChannel(function: _getChannelOnServer);
    if (channelResult.itsFailure) {
      return channelResult.cast();
    }

    _appLifecycleStateController = StreamController<AppLifecycleState>.broadcast();
    final streamResult = channelResult.content.getReceiver();
    if (streamResult.itsFailure) {
      return streamResult.cast();
    }
    streamResult.content.listen((state) {
      _appLifecycleStateController.add(state);
    }, onDone: () => dispose());

    return voidResult;
  }

  static FutureResult<void> _getChannelOnServer(Channel<AppLifecycleState, AppLifecycleState> channel, InvocationParameters para) async {
    final appResult = appManager.dynamicCastResult<FlutterManager>(
      errorMessage: const FixedOration(message: 'The application manager is not a FlutterManager, so it is not possible to get the current app lifecycle state'),
    );
    if (appResult.itsFailure) {
      return appResult.cast();
    }

    final statusObserver = appResult.content.statusObserver;

    final subscription = statusObserver.appLifecycleStateChanged.listen((state) {
      channel.sendItem(state).logIfFails(errorName: 'Failed to send app lifecycle state change through channel in FlutterStatusObserverIsolated');
    }, onDone: () => channel.dispose());

    await channel.onDispose.toFuture().whenComplete(() => subscription.cancel());

    return voidResult;
  }
}
