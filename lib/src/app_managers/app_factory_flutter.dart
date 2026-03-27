import 'package:maxi_flutter_framework/src/app_managers/flutter_native_manager.dart';
import 'package:maxi_framework/maxi_framework.dart';

ApplicationManager buildAppManagerImpl() {
  return FlutterNativeManager(isOriginalInstance: true);
}
