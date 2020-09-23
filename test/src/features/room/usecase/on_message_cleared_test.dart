import 'package:async/async.dart';
import 'package:dartz/dartz.dart';
import 'package:qiscus_chat_sdk/src/features/message/message.dart';
import 'package:qiscus_chat_sdk/src/features/realtime/realtime.dart';
import 'package:qiscus_chat_sdk/src/features/room/room.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

class MockService extends Mock implements IRealtimeService {}

void main() {
  IRealtimeService service;
  OnRoomMessagesCleared useCase;

  setUp(() {
    service = MockService();
    useCase = OnRoomMessagesCleared(service);
  });

  test('subscribe on message cleared', () async {
    const token = 'some-token';
    var chatRoom = ChatRoom(
      id: some(1),
    );
    when(service.subscribe(any)).thenReturn(Task(() async => right(null)));
    when(service.subscribeRoomCleared())
        .thenAnswer((_) => Stream.value(chatRoom));

    var params = TokenParams(token);
    var stream = await useCase.subscribe(params).run();

    var queue = StreamQueue(stream);
    expect(await queue.next, chatRoom.id);
    await queue.cancel();

    verify(service.subscribe('$token/n')).called(1);
    verify(service.subscribeRoomCleared()).called(1);
    verifyNoMoreInteractions(service);
  }, timeout: Timeout(Duration(seconds: 2)));
}
