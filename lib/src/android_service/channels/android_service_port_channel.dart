import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_flutter_framework/src/android_service/android_service_port.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServicePortChannel with DisposableMixin, LifecycleHub implements Channel<Map<String, dynamic>, Map<String, dynamic>> {
  final AndroidServicePort port;
  final ServiceInstance serviceInstance;
  final String streamName;

  late final StreamController<Map<String, dynamic>> _receiverStream;

  AndroidServicePortChannel({required this.port, required this.serviceInstance, required this.streamName}) {
    _receiverStream = lifecycleScope.joinStreamController(StreamController<Map<String, dynamic>>.broadcast());
    lifecycleScope.joinStream(stream: serviceInstance.on('fl.$streamName'), onData: (event) => _receiverStream.add(event ?? const {}));
  }

  @override
  Result<Stream<Map<String, dynamic>>> getReceiver() => _receiverStream.stream.asResultValue();

  @override
  Result<void> sendItem(Map<String, dynamic> item) {
    if (itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.unacceptedState,
        message: const FixedOration(message: 'Channel was discarded'),
      );
    }

    return volatileFunction(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'Failed to send item through service channel'),
      ),
      function: () => serviceInstance.invoke('sv.$streamName', item),
    );
  }

  @override
  void performObjectDiscard() {}
}
