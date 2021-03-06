import 'package:dartz/dartz.dart';
import 'package:qiscus_chat_sdk/src/core/api_request.dart';
import 'package:qiscus_chat_sdk/src/features/room/room_api_request.dart';
import 'package:test/test.dart';

import 'backend_response.dart';

void main() {
  group('ChatTargetRequest', () {
    var response = chatTargetResponse;
    var room = response['results']['room'] as Map<String, dynamic>;
    ChatTargetRequest request;

    setUp(() {
      request = ChatTargetRequest(userId: 'guest-101');
    });

    test('body', () {
      expect(request.body['emails'], ['guest-101']);
    });
    test('format', () {
      var data = request.format(response);
      expect(data.id, some(room['id'] as int));
      expect(data.name, some(room['room_name'] as String));
      expect(data.uniqueId, room['unique_id']);
    });
  });

  group('GetRoomById', () {
    var response = getRoomByIdResponse;
    var room = response['results']['room'] as Map<String, dynamic>;
    var messages =
        (response['results']['comments'] as List).cast<Map<String, dynamic>>();
    GetRoomByIdRequest request;

    setUp(() {
      request = GetRoomByIdRequest(roomId: 123);
    });

    test('body', () {
      expect(request.method, IRequestMethod.get);
      expect(request.params['id'], 123);
    });

    test('format', () {
      var data = request.format(response);
      expect(data.value1.id, some(room['id'] as int));
      expect(data.value1.uniqueId, room['unique_id']);

      expect(data.value2.length, 1);
      expect(data.value2.first.id, messages.first['id']);
      expect(data.value2.first.uniqueId,
          some(messages.first['unique_temp_id'] as String));
    });
  });

  group('AddParticipantRequest', () {
    var response = addParticipantResponse;
    var participants = (response['results']['participants_added'] as List)
        .cast<Map<String, dynamic>>();

    AddParticipantRequest request;
    setUp(() {
      request = AddParticipantRequest(roomId: 123, userIds: ['guest-101']);
    });

    test('body', () {
      expect(request.body['room_id'], '123');
      expect(request.body['emails'], ['guest-101']);
    });

    test('format', () {
      var data = request.format(response);
      expect(data.first.id, participants.first['email']);
      expect(data.first.name, some(participants.first['username'] as String));
    });
  });

  group('RemoveParticipantRequest', () {
    var response = removeParticipantResponse;
    var userIds = (response['results']['participants_removed'] as List) //
        .cast<String>();
    RemoveParticipantRequest request;

    setUp(() {
      request = RemoveParticipantRequest(roomId: 123, userIds: ['guest-101']);
    });

    test('body', () {
      expect(request.body['room_id'], '123');
      expect(request.body['emails'], ['guest-101']);
    });

    test('format', () {
      var data = request.format(response);
      expect(data.first, userIds.first);
    });
  });

  group('GetParticipantRequest', () {
    var response = getParticipantResponse;
    var participants = (response['results']['participants'] as List) //
        .cast<Map<String, dynamic>>();
    GetParticipantRequest request;

    setUp(() {
      request = GetParticipantRequest(roomUniqueId: '123');
    });

    test('body', () {
      expect(request.params['room_unique_id'], '123');
      expect(request.params['page'], null);
      expect(request.params['limit'], null);
      expect(request.params['sorting'], null);
    });

    test('format', () {
      var data = request.format(response);
      expect(data.first.id, participants.first['email']);
      expect(data.first.name, some(participants.first['email'] as String));
    });
  });

  group('GetAllRoomRequest', () {
    var response = getAllRoomResponse;
    var rooms = (response['results']['rooms_info'] as List) //
        .cast<Map<String, dynamic>>();
    GetAllRoomRequest request;

    setUp(() {
      request = GetAllRoomRequest();
    });

    test('body', () {
      expect(request.params['page'], null);
      expect(request.params['limit'], null);
      expect(request.params['show_participants'], null);
      expect(request.params['show_empty'], null);
      expect(request.params['show_removed'], null);
    });
    test('format', () {
      var data = request.format(response);
      expect(data.first.uniqueId, rooms.first['unique_id']);
      expect(data.first.id, some(rooms.first['id'] as int));
      expect(data.first.name, some(rooms.first['room_name'] as String));
    });
  });

  group('GetOrCreateChannelRequest', () {
    var response = getOrCreateChannelResponse;
    GetOrCreateChannelRequest request;

    setUp(() {
      request = GetOrCreateChannelRequest(uniqueId: 'unique-id');
    });

    test('body', () {
      expect(request.body['unique_id'], 'unique-id');
      expect(request.body['avatar_url'], null);
      expect(request.body['options'], null);
      expect(request.body['name'], null);
    });
    test('format', () {
      var data = request.format(response);
      var room = response['results']['room'] as Map<String, dynamic>;

      expect(data.uniqueId, room['unique_id']);
      expect(data.name, some(room['room_name'] as String));
      expect(data.id, some(room['id'] as int));
    });
  });

  group('CreateGroupRequest', () {
    CreateGroupRequest request;

    setUp(() {
      request = CreateGroupRequest(name: 'name', userIds: ['guest']);
    });

    test('body', () {
      expect(request.body['name'], 'name');
      expect(request.body['participants'], ['guest']);
      expect(request.body['avatar_url'], null);
      expect(request.body['options'], null);
    });

    test('format', () {
      var data = request.format(createGroupResponse);
      var room = createGroupResponse['results']['room'] as Map<String, dynamic>;

      expect(data.uniqueId, room['unique_id']);
      expect(data.id, some(room['id'] as int));
      expect(data.name, some(room['room_name'] as String));
      expect(data.avatarUrl, some(room['avatar_url'] as String));
    });
  });
}
