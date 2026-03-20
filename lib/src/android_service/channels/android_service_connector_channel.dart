import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/src/android_service/android_service_connector.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceConnectorChannel with DisposableMixin, InitializableMixin, LifecycleHub implements Channel<Map<String, dynamic>, Map<String, dynamic>> {
  final AndroidServiceConnector serviceConnector;
  final FlutterBackgroundService Function() backgroundServiceProvider;
  final String streamName;

  late final StreamController<Map<String, dynamic>> _receiverStream;
  late final FlutterBackgroundService _backgroundService;

  AndroidServiceConnectorChannel({required this.serviceConnector, required this.backgroundServiceProvider, required this.streamName});

  @override
  Result<void> performInitialization() {
    if (serviceConnector.itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.unacceptedState,
        message: const FixedOration(message: 'Service connector was discarded'),
      );
    }

    if (!serviceConnector.isInitialized) {
      return NegativeResult.controller(
        code: ErrorCode.unacceptedState,
        message: const FixedOration(message: 'Service connector is not initialized'),
      );
    }

    _receiverStream = joinStreamController(StreamController<Map<String, dynamic>>.broadcast());
    _backgroundService = backgroundServiceProvider();
    joinStream(
      stream: _backgroundService.on(streamName),
      onData: (item) {
        _receiverStream.add(item ?? const {});
      },
    );

    return voidResult;
  }

  @override
  Result<Stream<Map<String, dynamic>>> getReceiver() {
    final initResult = initialize();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    return _receiverStream.stream.asResultValue();
  }

  @override
  Result<void> sendItem(Map<String, dynamic> item) {
    final initResult = initialize();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    return volatileFunction(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'Failed to send item through service channel'),
      ),
      function: () => _backgroundService.invoke(streamName, item),
    );
  }
}
