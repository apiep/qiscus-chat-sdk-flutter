import 'package:async/async.dart';
import 'package:dartz/dartz.dart';
import 'package:qiscus_chat_sdk/src/core.dart';
import 'package:qiscus_chat_sdk/src/features/realtime/realtime.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

class MockService extends Mock implements IRealtimeService {}

void main() {
  IRealtimeService service;
  OnConnected onConnected;
  OnReconnecting onReconnecting;
  OnDisconnected onDisconnected;

  setUpAll(() {
    service = MockService();
    onConnected = OnConnected(service);
    onReconnecting = OnReconnecting(service);
    onDisconnected = OnDisconnected(service);
  });

  test('OnConnected.subscribe', () async {
    when(service.onConnected()).thenAnswer((_) => Stream.value(null));

    var stream = await onConnected.subscribe(noParams).run();
    stream.listen((_) {}, onError: (dynamic err) => fail(err.toString()));

    verify(service.onConnected()).called(1);
    verifyNoMoreInteractions(service);
  });

  test('OnReconnecting.subscribe', () async {
    when(service.onReconnecting()).thenAnswer((_) => Stream.value(null));

    var stream = await onReconnecting.subscribe(noParams).run();
    stream.listen((_) {}, onError: (dynamic err) => fail(err.toString()));

    verify(service.onReconnecting()).called(1);
    verifyNoMoreInteractions(service);
  });

  test('OnDisconnected.subscribe', () async {
    when(service.onDisconnected()).thenAnswer((_) => Stream.value(null));

    var stream = await onDisconnected.subscribe(noParams).run();

    stream.listen((_) {}, onError: (dynamic err) => fail(err.toString()));

    verify(service.onDisconnected()).called(1);
    verifyNoMoreInteractions(service);
  });
}
