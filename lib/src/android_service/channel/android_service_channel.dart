import 'dart:async';

import 'package:maxi_dart_framework/maxi_dart_framework.dart';

class AndroidServiceChannel with DisposableMixin, SynchronousInitializationMixin implements Channel<Map<String, dynamic>, Map<String, dynamic>> {
  final String name;
  final void Function(String method, [Map<String, dynamic>? args]) sender;
  final Stream<Map<String, dynamic>?> Function(String method) streamBuilder;

  late final StreamController<Map<String, dynamic>> _controller;
  late final StreamSubscription<Map<String, dynamic>?> _receiverStream;

  AndroidServiceChannel(this.name, this.sender, this.streamBuilder);

  @override
  Result<void> performInitialization() => resultScopeVoid(() {
    checkDisposed().$;

    _receiverStream = streamBuilder(name).listen((event) {
      _controller.add(event ?? const {});
    }, onDone: dispose);

    _controller = StreamController<Map<String, dynamic>>.broadcast();
  });

  @override
  Result<Stream<Map<String, dynamic>>> getReceiver() => resultScopeValue(() {
    checkDisposed().$;
    initialize().$;
    return _controller.stream;
  });

  @override
  Result<void> sendItem(Map<String, dynamic> item) => resultScopeVoid(() {
    checkDisposed().$;
    initialize().$;
    sender(name, item);
  });

  @override
  void performDisposal() {
    _controller.close();
    _receiverStream.cancel();
  }
}
