import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:maxi_flutter_framework/src/app_managers/flutter_manager.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer_isolated.dart';
import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer_server.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:maxi_framework/maxi_framework_native_impl.dart';

class _FlutterNativeManagerConfig {
  final bool isDebug;
  final String workingPath;

  _FlutterNativeManagerConfig({required this.isDebug, required this.workingPath});
}

class FlutterNativeManager
    with DisposableMixin, AsynchronouslyInitializedMixin, LifecycleHub, WidgetsBindingObserver
    implements ApplicationManager, NativeAppManager, IsolatedReplicableApplicationManager, FlutterManager {
  bool _isDebug = false;
  String _currentWorkingPath = '¿?';
  _FlutterNativeManagerConfig? _previousConfig;
  Channel<(dynamic, StackTrace), (dynamic, StackTrace)>? _exceptionChannel;

  late final bool _isOriginalInstance;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isFlutter => true;

  @override
  bool get isFuchsia => Platform.isFuchsia;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get isLinux => Platform.isLinux;

  @override
  bool get isMacOS => Platform.isMacOS;

  @override
  bool get isWeb => false;

  @override
  bool get isWindows => Platform.isWindows;

  @override
  bool get isMovil => isAndroid || isIOS;

  @override
  bool get isDebug => isInitialized && _isDebug;

  @override
  bool get isDesktop => isWindows || isLinux || isMacOS;

  @override
  bool get isService => false;

  @override
  late final FlutterStatusObserver statusObserver;

  FlutterNativeManager({required bool isOriginalInstance, FlutterStatusObserver? observer}) {
    _isOriginalInstance = isOriginalInstance;
    if (observer == null) {
      if (_isOriginalInstance) {
        statusObserver = FlutterStatusObserverServer();
      } else {
        statusObserver = FlutterStatusObserverIsolated();
      }
    } else {
      statusObserver = observer;
    }

    if (statusObserver is Disposable) {
      lifecycleScope.joinDisposableObject(statusObserver as Disposable);
    }
  }

  factory FlutterNativeManager._withConfig(_FlutterNativeManagerConfig config) {
    final manager = FlutterNativeManager(isOriginalInstance: false);
    manager._previousConfig = config;
    manager._isDebug = config.isDebug;
    manager._currentWorkingPath = config.workingPath;
    return manager;
  }

  @override
  Future<Result<void>> performInitialize() async {
    if (!_isOriginalInstance) {
      return voidResult;
    }

    if (_previousConfig != null) {
      _isDebug = _previousConfig!.isDebug;
      _currentWorkingPath = _previousConfig!.workingPath;
      return voidResult;
    }

    final debugModeResult = await CheckItsInDebugMode().execute();
    if (debugModeResult.itsFailure) return debugModeResult.cast();
    _isDebug = debugModeResult.content;

    if (_currentWorkingPath == '¿?') {
      final prepareWorkspaceResult = await PrepareNativeAppWorkspace(isDebug: _isDebug).execute();
      if (prepareWorkspaceResult.itsFailure) return prepareWorkspaceResult.cast();
      _currentWorkingPath = prepareWorkspaceResult.content;
    }

    WidgetsFlutterBinding.ensureInitialized();

    if (statusObserver is AsynchronouslyInitialized) {
      final statusObserverInitResult = await (statusObserver as AsynchronouslyInitialized).initialize();
      if (statusObserverInitResult.itsFailure) return statusObserverInitResult.cast();
    }

    if (statusObserver is Initializable) {
      final statusObserverInitResult = (statusObserver as Initializable).initialize();
      if (statusObserverInitResult.itsFailure) return statusObserverInitResult.cast();
    }

    return voidResult;
  }

  @override
  FileOperator buildFileOperator(FileReference file) => NativeFileOperator(fileReference: file, appManager: this);

  @override
  FolderOperator buildFolderOperator(FolderReference folder) => NativeFolderOperator(folderReference: folder, appManager: this);

  @override
  FutureResult<void> defineWorkingPath(String path) {
    _currentWorkingPath = path;
    return initialize();
  }

  @override
  FutureResult<String> getWorkingPath() async {
    final initResult = await initialize();
    if (initResult.itsFailure) return initResult.cast();
    return ResultValue(content: _currentWorkingPath);
  }

  @override
  FutureResult<Functionality<ApplicationManager>> cloneToIsolate() async {
    final initResult = await initialize();
    if (initResult.itsFailure) return initResult.cast();
    return ResultValue(
      content: _CloneNativeFlutterAppManager(
        config: _FlutterNativeManagerConfig(isDebug: _isDebug, workingPath: _currentWorkingPath),
      ),
    );
  }

  @override
  Channel<(dynamic, StackTrace), (dynamic, StackTrace)> get exceptionChannel {
    if (_exceptionChannel == null) {
      final master = MasterChannel<(dynamic, StackTrace), (dynamic, StackTrace)>();
      _exceptionChannel = master;
      return master.buildConnector().exceptionIfFails(detail: 'Exception channel for NativeFlutterAppManager');
    }

    if (_exceptionChannel is MasterChannel<(dynamic, StackTrace), (dynamic, StackTrace)>) {
      return (_exceptionChannel as MasterChannel<(dynamic, StackTrace), (dynamic, StackTrace)>).buildConnector().exceptionIfFails(detail: 'Exception channel for NativeFlutterAppManager');
    }

    return _exceptionChannel!;
  }

  @override
  Result<void> changeExceptionChannel(Channel<(dynamic, StackTrace), (dynamic, StackTrace)> channel) {
    final itsDiscarded = failIfItsDiscarded();
    if (itsDiscarded.itsFailure) {
      return itsDiscarded.cast();
    }

    if (_exceptionChannel != null) {
      channel.reflectChannel(_exceptionChannel!);
    }
    _exceptionChannel = channel;
    return voidResult;
  }

  @override
  FutureResult<void> changeDebugState(bool isDebug) async {
    final initResult = await initialize();
    if (initResult.itsFailure) return initResult.cast();
    _isDebug = isDebug;
    return voidResult;
  }

  @override
  void performInitializedObjectDiscard() {
    super.performInitializedObjectDiscard();
  }
}

class _CloneNativeFlutterAppManager with FunctionalityMixin<ApplicationManager> {
  final _FlutterNativeManagerConfig config;

  _CloneNativeFlutterAppManager({required this.config});

  @override
  FutureOr<Result<ApplicationManager>> runInternalFuncionality() => FlutterNativeManager._withConfig(config).asResultValue();
}
