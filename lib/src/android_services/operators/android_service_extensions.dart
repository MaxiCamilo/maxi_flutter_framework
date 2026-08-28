import 'dart:developer';

import 'package:maxi_flutter_framework/src/android_services/operators/android_service_interface.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:rxdart/rxdart.dart';

extension AndroidServiceExtensions on AndroidServiceInterface {
  FutureResult<void> sendRequest({required String name, Map<String, dynamic> data = const {}}) async {
    if (itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service was discarded'),
      );
    }
    if (!isInitialized) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service is not initialized'),
      );
    }

    final messageName = '${isServer ? 'ser' : 'cli'}.$name';

    final newChannelResult = await buildChannel(messageName);
    if (newChannelResult.itsFailure) {
      return newChannelResult.cast();
    }

    return newChannelResult.content.sendItem(data).onCompleteVoid((_) => newChannelResult.content.dispose());
  }

  FutureResult<Map<String, dynamic>> waitRequest({required String name, required Duration timeout}) async {
    if (itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service was discarded'),
      );
    }
    if (!isInitialized) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service is not initialized'),
      );
    }

    final desiredMessage = '${isServer ? 'cli' : 'ser'}.$name';
    final newChannelResult = await buildChannel(desiredMessage);
    if (newChannelResult.itsFailure) {
      return newChannelResult.cast();
    }

    final connector = newChannelResult.content;

    final streamResult = connector.getReceiver();
    if (streamResult.itsFailure) {
      connector.dispose();
      return streamResult.cast();
    }

    return streamResult.content.waitItem(timeout: timeout).onCompleteVoid((_) => connector.dispose());
  }

  FutureResult<Stream<Map<String, dynamic>>> listenRequest({required String name}) async {
    if (itWasDiscarded) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service was discarded'),
      );
    }
    if (!isInitialized) {
      return NegativeResult.controller(
        code: ErrorCode.externalFault,
        message: const FixedOration(message: 'The service is not initialized'),
      );
    }
    final desiredMessage = '${isServer ? 'cli' : 'ser'}.$name';
    final newChannelResult = await buildChannel(desiredMessage);
    if (newChannelResult.itsFailure) {
      return newChannelResult.cast();
    }

    final connector = newChannelResult.content;
    final streamResult = connector.getReceiver();
    if (streamResult.itsFailure) {
      connector.dispose();
      return streamResult.cast();
    }

    return ResultValue(content: streamResult.content.doOnCancel(() => connector.dispose()));
  }

  FutureResult<void> listenAndResponse({required String name, required FutureResult<Map<String, dynamic>> Function(Map<String, dynamic> data) onRequest}) async {
    await for (final part in await listenRequest(name: name).waitContentOrThrow()) {
      final response = await onRequest(part);
      if (response.itsFailure) {
        log('Failed to process request: $part');
        continue;
      }

      await sendRequest(name: name, data: response.content).logIfFails(errorName: 'listenAndResponse');
    }

    return voidResult;
  }

  FutureResult<Map<String, dynamic>> sendAndWaitResponse({required String name, required Duration timeout, Map<String, dynamic> data = const {}}) async {
    final futureWait = waitRequest(name: name, timeout: timeout);
    final sendResult = await sendRequest(name: name, data: data);
    if (sendResult.itsFailure) {
      futureWait.ignore();
      return sendResult.cast();
    }

    return await futureWait;
  }
}
