import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:maxi_dart_framework/maxi_dart_framework.dart';

/// Quién originó el cambio de URL.
enum RouteOrigin {
  /// El browser (atrás/adelante, URL tipeada) o un deep link del SO.
  platform,

  /// El propio código llamó a UrlController.go().
  app,
}

/// Evento que recibe el programador ante cada cambio.
class RouteEvent {
  const RouteEvent({
    required this.uri,
    required this.previous,
    required this.origin,
    this.state,
  });

  final Uri uri;
  final Uri previous;
  final RouteOrigin origin;
  final Object? state;

  @override
  String toString() => 'RouteEvent($previous -> $uri, $origin)';
}

class MaxiRouterManager extends ChangeNotifier with WidgetsBindingObserver implements Disposable {
  final Uri? Function(MaxiRouterManager router, RouteEvent event)? interceptor;
  final bool Function(MaxiRouterManager router)? onBack;

  MaxiRouterManager({this.interceptor, this.onBack});

  late Uri _current;
  Uri get current => _current;

  StreamController<RouteEvent>? _events;

  bool _initialized = false;

  Result<void> initialize() => resultScopeVoid(() {
    if (_initialized) return;

    //usePathUrlStrategy();
    volatileScope(message: Oration('Initializing Flutter binding failed'), function: () => WidgetsFlutterBinding.ensureInitialized()).$;
    _current = Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    SystemNavigator.selectMultiEntryHistory();
    WidgetsBinding.instance.addObserver(this);

    _events = StreamController<RouteEvent>.broadcast();
    _initialized = true;
  });

  Result<void> go(String location, {Object? state, bool replace = false}) {
    return resultScopeVoid(() {
      initialize().$;
      _apply(Uri.parse(location), RouteOrigin.app, state, replace: replace);
    });
  }

  Result<void> _apply(Uri uri, RouteOrigin origin, Object? state, {bool replace = false}) => resultScopeVoid(() {
    final event = RouteEvent(
      uri: uri,
      previous: _current,
      origin: origin,
      state: state,
    );

    Uri? target = interceptor == null ? uri : interceptor!(this, event);

    if (target == null) {
      // Cancelado: si vino del browser, restauramos la URL.
      if (origin == RouteOrigin.platform) _report(_current, replace: true);
      return;
    }

    final redirected = target != uri;
    if (target == _current && !redirected) return;

    if (target.toString().isNotEmpty && target.toString()[0] != '/') target = Uri.parse('/${target.toString()}');

    final previous = _current;
    _current = target;

    _report(target, state: state, replace: replace || origin == RouteOrigin.platform);

    _events?.add(
      RouteEvent(
        uri: target,
        previous: previous,
        origin: origin,
        state: state,
      ),
    );
    notifyListeners();
  });

  Result<void> _report(Uri uri, {Object? state, bool replace = false}) => resultScopeVoid(() {
    //SystemNavigator.selectMultiEntryHistory();
    SystemNavigator.routeInformationUpdated(
      uri: uri,
      state: state,
      replace: replace,
    );
  });

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    _apply(routeInformation.uri, RouteOrigin.platform, routeInformation.state).logIfFailure('Failed to apply route information');
    return true;
  }

  @override
  Future<bool> didPopRoute() async => onBack?.call(this) ?? false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.close();
    super.dispose();
  }
}
