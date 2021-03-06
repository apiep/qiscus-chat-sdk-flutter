import 'package:dartz/dartz.dart';
import 'package:qiscus_chat_sdk/src/features/room/repository.dart';
import 'package:qiscus_chat_sdk/src/features/room/room.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

class MockRepo extends Mock implements IRoomRepository {}

void main() {
  IRoomRepository repo;
  GetRoomByUserIdUseCase useCase;

  setUpAll(() {
    repo = MockRepo();
    useCase = GetRoomByUserIdUseCase(repo);
  });

  test('get room by userId successfully', () async {
    when(repo.getRoomWithUserId(any)).thenReturn(Task(() async {
      return right(ChatRoom(
        id: some(123),
        extras: some(imap<String, dynamic>(<String, dynamic>{})),
        avatarUrl: some('avatar-url'),
        name: some('name'),
        uniqueId: 'unique-id',
        type: QRoomType.single,
        lastMessage: none(),
        participants: none(),
        sender: none(),
        totalParticipants: some(0),
        unreadCount: some(0),
      ));
    }));

    var params = UserIdParams('user-id');
    var resp = await useCase.call(params).run();

    resp.fold((l) => fail(l.message), (r) {
      expect(r.id, some<int>(123));
    });

    verify(repo.getRoomWithUserId('user-id')).called(1);
    verifyNoMoreInteractions(repo);
  });
}
