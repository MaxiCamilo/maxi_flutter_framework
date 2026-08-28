import 'dart:async';
import 'dart:developer';

import 'package:grpc/grpc.dart' show Service, ServerInterceptor, Interceptor, ServerKeepAliveOptions, CodecRegistry, GrpcError;
import 'package:maxi_flutter_framework/maxi_flutter_framework.dart';
import 'package:maxi_flutter_framework/src/android_services/grpc/android_service_grpc_instance.dart';
import 'package:maxi_framework/maxi_framework.dart';

class AndroidServiceGrpcServer with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub {
  final AndroidServiceInterface androidConnection;
  final List<Service> grpcServices;
  final String name;
  final ServerKeepAliveOptions keepAliveOptions;
  final List<Interceptor> interceptors;
  final List<ServerInterceptor> serverInterceptors;
  final CodecRegistry? codecRegistry;
  final void Function(GrpcError error, StackTrace? trace)? errorHandler;

  late DisposableList<AndroidServiceGrpcInstance> _instances;

  int _lastIdentifier = 0;

  AndroidServiceGrpcServer({
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
    final initApp = await androidConnection.initialize();
    if (initApp.itsFailure) {
      return initApp.cast();
    }

    _instances = lifecycleScope.joinDisposableObject(DisposableList<AndroidServiceGrpcInstance>());

    scheduleMicrotask(() async {
      await androidConnection.listenAndResponse(name: name, onRequest: _processRequest);
      dispose();
    });

    

    return voidResult;
  }

  Future<Result<Map<String, dynamic>>> _processRequest(Map<String, dynamic> content) async {
    final command = content['grpc']?.toString() ?? '';

    if (command == '1') {
      _lastIdentifier += 1;
      final newId = _lastIdentifier;
      final instance = AndroidServiceGrpcInstance(
        identifier: newId,
        androidConnection: androidConnection,
        grpcServices: grpcServices,
        name: name,
        codecRegistry: codecRegistry,
        errorHandler: errorHandler,
        interceptors: interceptors,
        keepAliveOptions: keepAliveOptions,
        serverInterceptors: serverInterceptors,
      );

      final initNewInstance = await instance.initialize();
      if (initNewInstance.itsFailure) {
        log('Failed to initialize new instance: ${initNewInstance.error}');
        return ResultValue(content: {});
      }

      _instances.add(instance);
    } else if (command == '2') {
      final id = content['id'] as int;
      final insance = _instances.selectItem((x) => x.identifier == id);
      insance?.dispose();
    }
    return ResultValue(content: {});
  }
}
