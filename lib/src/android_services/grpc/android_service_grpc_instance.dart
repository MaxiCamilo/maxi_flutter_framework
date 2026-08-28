import 'dart:async';
import 'dart:developer';

import 'package:grpc/grpc.dart' show ServerKeepAliveOptions, Service, Interceptor, ServerInterceptor, CodecRegistry, GrpcError, Server;
import 'package:http2/transport.dart' as http2 show ServerTransportConnection;
import 'package:maxi_flutter_framework/maxi_flutter_framework.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceGrpcInstance with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub implements StreamSink<List<int>> {
  final AndroidServiceInterface androidConnection;
  final List<Service> grpcServices;
  final String name;
  final ServerKeepAliveOptions keepAliveOptions;
  final List<Interceptor> interceptors;
  final List<ServerInterceptor> serverInterceptors;
  final CodecRegistry? codecRegistry;
  final void Function(GrpcError error, StackTrace? trace)? errorHandler;
  final int identifier;

  Server? _grpcInstance;

  AndroidServiceGrpcInstance({
    required this.identifier,
    required this.androidConnection,
    required this.grpcServices,
    required this.name,
    this.keepAliveOptions = const ServerKeepAliveOptions(),
    this.interceptors = const <Interceptor>[],
    this.serverInterceptors = const <ServerInterceptor>[],
    this.codecRegistry,
    this.errorHandler,
  });

  @override
  Future<Result<void>> performInitialize() async {
    final listenCancelResult = await lifecycleScope.joinFutureStream(
      function: () => androidConnection.listenRequest(name: '$name.$identifier.cancel'),
      onData: (event) => dispose(),
    );
    if (listenCancelResult.itsFailure) {
      return listenCancelResult.cast();
    }

    final streamResult = await androidConnection.listenRequest(name: '$name.$identifier');
    if (streamResult.itsFailure) {
      return streamResult.cast();
    }

    final conn = http2.ServerTransportConnection.viaStreams(
      streamResult.content.map((x) {
        return (x['data'] as Iterable).cast<int>().toList();
      }),
      this,
    );

    _grpcInstance = Server.create(
      services: grpcServices,
      codecRegistry: codecRegistry,
      errorHandler: errorHandler,
      interceptors: interceptors,
      keepAliveOptions: keepAliveOptions,
      serverInterceptors: serverInterceptors,
    );

    final connectionResult = await volatileFuture(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'Creation of the grpc instance failed'),
      ),
      function: () => _grpcInstance!.serveConnection(connection: conn),
    );
    if (connectionResult.itsFailure) {
      return connectionResult.cast();
    }

    lifecycleScope.joinStream(stream: flutterAppManager.onInterfaceDetached, onData: (_) => dispose());

    return voidResult;
  }

  @override
  void performInitializedObjectDiscard() {
    super.performInitializedObjectDiscard();

    androidConnection.sendRequest(name: '$name.$identifier.cancel');
    androidConnection.sendRequest(name: 'grpc', data: {'id': 2});
    _grpcInstance?.shutdown();
    _grpcInstance = null;
  }

  @override
  void add(List<int> event) {
    androidConnection.sendRequest(name: '$name.$identifier', data: {'data': event}).injectNegativeLogic((x) {
      log('[GprcAndroidServer] Data transmission to the client failed: $x');
      dispose();
    });
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    log('Error send grpc server error on android service: $error [$stackTrace]');
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) {
    final completer = Completer();

    lifecycleScope.joinStreamSubscription(
      stream.listen(
        add,
        onError: addError,
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );

    return completer.future;
  }

  @override
  Future<dynamic> close() async {
    dispose();
  }

  @override
  Future<dynamic> get done => onDispose.toFuture();
}
