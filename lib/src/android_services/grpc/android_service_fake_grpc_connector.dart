import 'dart:async';
import 'dart:developer';

import 'package:grpc/grpc.dart';
import 'package:http2/transport.dart' as http2;
import 'package:maxi_flutter_framework/maxi_flutter_framework.dart';
import 'package:maxi_framework/maxi_framework.dart';
import 'package:maxi_proto_framework/maxi_proto_framework.dart';

extension ConnectionServerGrpcAndroid on Server {
  //http2.ServerTransportConnection.viaStreams(incoming, outgoing)

  FutureResult<void> connectToAndroidServer({required AndroidServiceInterface service, required String name}) async {
    final channelResult = await service.buildChannel(name);
    if (channelResult.itsFailure) {
      return channelResult.cast();
    }

    final channel = channelResult.content;
    final streamResult = channel.getReceiver();
    if (streamResult.itsFailure) {
      return streamResult.cast();
    }

    final incoming = streamResult.content;

    final conn = http2.ServerTransportConnection.viaStreams(_convertToData(incoming), _ChannelCaster(channel: channel));

    return serveConnection(connection: conn).toFutureResult(errorMessage: const FixedOration(message: 'Failed to serve connection'));
  }
}

Stream<List<int>> _convertToData(Stream<Map<String, dynamic>> incoming) async* {
  await for (final data in incoming) {
    final content = tryFunction(
      const FixedOration(message: 'It was expected that a "data" file containing binary code would be received'),
      () => (data['data'] as Iterable).cast<int>().toList(),
    ).logIfFails(errorName: 'Failed to extract data from incoming map').content;

    yield content;
  }

  print('CLOSE STREAM');
}

class _ChannelCaster implements StreamSink<List<int>> {
  final Channel<Map<String, dynamic>, Map<String, dynamic>> channel;

  const _ChannelCaster({required this.channel});

  @override
  void add(List<int> event) {
    channel.sendItem({'data': event}).logIfFails(errorName: 'Failed to send data to channel');
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    log('Error occurred in _ChannelCaster', error: error, stackTrace: stackTrace);
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    final completer = Completer<void>();
    final sub = stream.listen(
      (event) => add(event),
      onError: (error, stackTrace) => addError(error, stackTrace),
      onDone: () => completer.complete(),
    );

    channel.onDispose.whenComplete(() => sub.cancel());
    return completer.future;
  }

  @override
  Future<dynamic> close() async {
    print('CLOSE!');
    channel.dispose();
  }

  @override
  Future<dynamic> get done => channel.onDispose.toFuture();
}

FutureResult<ClientTransportConnectorChannel> buildGrpcAndroidServiceClient({
  required AndroidServiceInterface service,
  required String name,
  http2.ClientSettings? settings,
  ChannelOptions options = const ChannelOptions(),
}) async {
  final channelResult = await service.buildChannel(name);
  if (channelResult.itsFailure) {
    return channelResult.cast();
  }

  final channel = channelResult.content;
  final streamResult = channel.getReceiver();
  if (streamResult.itsFailure) {
    return streamResult.cast();
  }

  final incoming = streamResult.content;
  final stream = _convertToData(incoming);

  final outgoing = _ChannelCaster(channel: channel);

  return ResultValue(
    content: CustomGrpcConnector(incoming: stream, outgoing: outgoing, options: options, settings: settings),
  );
}
