import 'package:maxi_flutter_framework/src/observers/status_observe/flutter_status_observer.dart';
import 'package:maxi_framework/maxi_framework.dart';

abstract interface class AndroidServiceInterface implements AsynchronouslyInitialized, FlutterStatusObserver {
  bool get isServer;

  FutureResult<bool> checkIsServiceRunning();

  FutureResult<void> startPing();

  FutureResult<Channel<Map<String, dynamic>, Map<String, dynamic>>> buildChannel(String name);

  FutureResult<void> closeService();
}
