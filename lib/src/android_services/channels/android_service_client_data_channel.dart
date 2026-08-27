import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceClientDataChannel with DisposableMixin, LifecycleHub implements Channel<Map<String, dynamic>, Map<String, dynamic>> {
  final ServiceInstance service;
  final String name;

  AndroidServiceClientDataChannel({required this.service, required this.name});

  @override
  Result<Stream<Map<String, dynamic>>> getReceiver() {
    if (itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.discontinuedFunctionality,
        message: const FixedOration(message: 'Cannot listen for data because the main service channel was disposed'),
      );
    }

    final streamResult = tryFunction(
      FlexibleOration(message: 'Failed to get receiver for main service channel %1', textParts: [name]),
      () => service.on(name).map<Map<String, dynamic>>((x) => x ?? {}),
    );

    if (streamResult.itsFailure) {
      return streamResult.cast();
    }

    return lifecycleScope.connectStream(streamResult.content);
  }

  @override
  Result<void> sendItem(Map<String, dynamic> item) {
    if (itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.discontinuedFunctionality,
        message: const FixedOration(message: 'Cannot send data because the main service channel was disposed'),
      );
    }

    return tryFunction(
      FlexibleOration(message: 'Failed to send item for main service channel %1', textParts: [name]),
      () => service.invoke(name, item),
    );
  }

  @override
  void performObjectDiscard() {}
}
