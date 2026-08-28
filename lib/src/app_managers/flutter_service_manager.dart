import 'package:maxi_flutter_framework/src/android_services/operators/android_service_client.dart';

import 'package:maxi_flutter_framework/src/app_managers/flutter_manager.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:maxi_framework/maxi_framework_native_impl.dart';

class FlutterServiceManager with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub implements ApplicationManager, NativeAppManager, IsolatedReplicableApplicationManager, FlutterManager {
  final AndroidServiceClient serviceClient;

  bool _isDebug = false;
  String _currentWorkingPath = '¿?';

  @override
  bool get isAndroid => true;

  @override
  bool get isDebug => false;

  @override
  bool get isDesktop => false;

  @override
  bool get isFlutter => true;

  @override
  bool get isFuchsia => false;

  @override
  bool get isIOS => false;

  @override
  bool get isLinux => false;

  @override
  bool get isMacOS => false;

  @override
  bool get isMovil => true;

  @override
  bool get isService => true;

  @override
  bool get isWeb => false;

  @override
  bool get isWindows => false;

  @override
  FlutterStatusObserver get statusObserver => serviceClient;

  FlutterServiceManager({required this.serviceClient});

  @override
  Future<Result<void>> performInitialize() async {
    final debugModeResult = await CheckItsInDebugMode().execute();
    if (debugModeResult.itsFailure) return debugModeResult.cast();
    _isDebug = debugModeResult.content;

    if (_currentWorkingPath == '¿?') {
      final prepareWorkspaceResult = await PrepareNativeAppWorkspace(isDebug: _isDebug).execute();
      if (prepareWorkspaceResult.itsFailure) return prepareWorkspaceResult.cast();
      _currentWorkingPath = prepareWorkspaceResult.content;
    }

    return voidResult;
  }

  @override
  FileOperator buildFileOperator(FileReference file) {
    // TODO: implement buildFileOperator
    throw UnimplementedError();
  }

  @override
  FolderOperator buildFolderOperator(FolderReference folder) {
    // TODO: implement buildFolderOperator
    throw UnimplementedError();
  }

  @override
  FutureResult<void> changeDebugState(bool isDebug) {
    // TODO: implement changeDebugState
    throw UnimplementedError();
  }

  @override
  Result<void> changeExceptionChannel(Channel<(dynamic, StackTrace), (dynamic, StackTrace)> channel) {
    // TODO: implement changeExceptionChannel
    throw UnimplementedError();
  }

  @override
  FutureResult<Functionality<ApplicationManager>> cloneToIsolate() {
    // TODO: implement cloneToIsolate
    throw UnimplementedError();
  }

  @override
  FutureResult<void> defineWorkingPath(String path) {
    // TODO: implement defineWorkingPath
    throw UnimplementedError();
  }

  @override
  // TODO: implement exceptionChannel
  Channel<(dynamic, StackTrace), (dynamic, StackTrace)> get exceptionChannel => throw UnimplementedError();

  @override
  FutureResult<String> getWorkingPath() {
    // TODO: implement getWorkingPath
    throw UnimplementedError();
  }
}
