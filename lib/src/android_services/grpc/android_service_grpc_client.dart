import 'dart:async';

import 'package:grpc/grpc.dart' as grpc;
import 'package:maxi_flutter_framework/maxi_flutter_framework.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceGrpcClient<T extends grpc.Client> with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub {
  final T Function() instanceBuilder;
  final AndroidServiceInterface androidConnection;
  final String name;

  T? _instance;

  AndroidServiceGrpcClient({required this.instanceBuilder, required this.androidConnection, required this.name});

  @override
  Future<Result<void>> performInitialize() async {
    // TODO: implement performInitialize
    throw UnimplementedError();
  }

  FutureResult<R> executeResult<R>(FutureOr<R> Function(T) func) async {
    final initResult = await initialize();
    if (initResult.itsFailure) {
      return initResult.cast();
    }

    return volatileFuture(
      error: (ex, st) => ExceptionResult(
        exception: ex,
        stackTrace: st,
        message: const FixedOration(message: 'An error occurred while executing a gRPC request'),
      ),
      function: () => func(_instance!),
    );
  }

  @override
  void performInitializedObjectDiscard() {
    super.performInitializedObjectDiscard();
    _instance = null;
  }
}
