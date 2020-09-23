import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:mockito/mockito.dart';
import 'package:qiscus_chat_sdk/src/features/realtime/realtime.dart';
import 'package:qiscus_chat_sdk/src/features/user/user.dart';
import 'package:test/test.dart';

class MockRealtimeService extends Mock implements IRealtimeService {}

void main() {
  group('User Realtime', () {
    IRealtimeService service;

    setUpAll(() {
      service = MockRealtimeService();
    });

    group('TypingUseCase', () {
      TypingUseCase useCase;
      setUpAll(() {
        service = MockRealtimeService();
        useCase = TypingUseCase(service);
      });

      test('publish typing data', () async {
        var data = Typing(
          isTyping: true,
          roomId: 123,
          userId: 'userId',
        );

        when(service.publishTyping(
          isTyping: anyNamed('isTyping'),
          userId: anyNamed('userId'),
          roomId: anyNamed('roomId'),
        )).thenReturn(right(null));

        var resp = await useCase.call(data).run();
        resp.fold((l) => fail(l.message), (r) {});

        verify(service.publishTyping(
          isTyping: data.isTyping,
          userId: data.userId,
          roomId: data.roomId,
        )).called(1);
        verifyNoMoreInteractions(service);
      });

      test('subscribe typing', () async {
        var param = Typing(roomId: 123, userId: '123');
        final topic = TopicBuilder.typing(
          param.roomId.toString(),
          param.userId,
        );
        when(service.subscribe(any)).thenReturn(Task(() async {
          return right(null);
        }));

        when(service.subscribeUserTyping(roomId: param.roomId)).thenAnswer((_) {
          return Stream.fromIterable([
            UserTyping(userId: 'user-id-1', roomId: 1, isTyping: true),
            UserTyping(userId: 'user-id-2', roomId: 1, isTyping: true),
            UserTyping(userId: 'user-id-3', roomId: 1, isTyping: true),
            UserTyping(userId: 'user-id-4', roomId: 1, isTyping: true),
          ]);
        });

        var stream = await useCase.subscribe(param).run();
        await expectLater(
          stream,
          emitsAnyOf(<Typing>[
            Typing(userId: 'user-id-1', roomId: 1, isTyping: true),
            Typing(userId: 'user-id-2', roomId: 1, isTyping: true),
            Typing(userId: 'user-id-3', roomId: 1, isTyping: true),
            Typing(userId: 'user-id-4', roomId: 1, isTyping: true),
          ]),
        );

        verify(service.subscribe(topic)).called(1);
        verify(service.subscribeUserTyping(roomId: param.roomId)).called(1);
        verifyNoMoreInteractions(service);
      });
    });

    group('PresenceUseCase', () {
      PresenceUseCase useCase;

      setUpAll(() {
        service = MockRealtimeService();
        useCase = PresenceUseCase(service);
      });

      test('publish presence data successfully', () async {
        var params = Presence(
          userId: 'user-id',
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        when(service.publishPresence(
          isOnline: anyNamed('isOnline'),
          lastSeen: anyNamed('lastSeen'),
          userId: anyNamed('userId'),
        )).thenAnswer((_) => right(null));

        var resp = await useCase.call(params).run();
        resp.fold((l) => fail(l.message), (r) {});

        verify(service.publishPresence(
          isOnline: params.isOnline,
          lastSeen: params.lastSeen,
          userId: params.userId,
        )).called(1);
        verifyNoMoreInteractions(service);
      });

      test('subscribe presence data successfully', () async {
        var params = Presence(
          userId: 'user-id',
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        var topic = TopicBuilder.presence(params.userId);
        final date = DateTime.now();

        when(service.subscribe(any)).thenReturn(Task.delay(() => right(null)));
        when(service.subscribeUserPresence(
          userId: anyNamed('userId'),
        )).thenAnswer((_) {
          return Stream.value(UserPresence(
            userId: 'user-id',
            lastSeen: date,
            isOnline: true,
          ));
        });

        var stream = await useCase.subscribe(params).run();
        stream.take(1).listen(expectAsync1((Presence presence) {
              print('type: ${presence.runtimeType}');
              print('presence: $presence');
              expect(presence.isOnline, true);
              expect(presence.lastSeen, date);
            }, count: 1, max: 1));
        // expect(
        //   stream,
        //   emitsInOrder(<StreamMatcher>[
        //     emits(Presence(
        //       userId: 'user-id-1',
        //       lastSeen: date,
        //       isOnline: true,
        //     )),
        //     // emits(Presence(
        //     //   userId: 'user-id-2',
        //     //   lastSeen: date,
        //     //   isOnline: true,
        //     // )),
        //   ]),
        // );

        verify(service.subscribe(topic)).called(1);
        verify(service.subscribeUserPresence(userId: params.userId)).called(1);
        verifyNoMoreInteractions(service);
      });
    });
  }, timeout: Timeout(const Duration(seconds: 2)));
}
