import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:qiscus_chat_sdk/src/core/core.dart';
import 'package:qiscus_chat_sdk/src/core/extension.dart';
import 'package:qiscus_chat_sdk/src/core/storage.dart';
import 'package:qiscus_chat_sdk/src/features/message/entity.dart';
import 'package:qiscus_chat_sdk/src/features/realtime/service.dart';
import 'package:sealed_unions/factories/doublet_factory.dart';
import 'package:sealed_unions/implementations/union_2_impl.dart';
import 'package:sealed_unions/union_2.dart';

import 'mqtt_events.dart';

class MqttServiceImpl implements IRealtimeService {
  MqttServiceImpl(this._getClient, this._s, this._logger, this._dio) {
    _mqtt.onConnected = () => log('on mqtt connected');
    _mqtt.onDisconnected = () {
      log('on mqtt disconnected');
      _onDisconnected(_mqtt.connectionStatus);
    };
    _mqtt.onSubscribed = (topic) {
      _subscribedTopics.add(topic);
      log('on mqtt subscribed: $topic');
    };
    _mqtt.onUnsubscribed = (topic) => log('on mqtt unsubscribed: $topic');

    if (_s.isRealtimeEnabled) {
      _mqtt
          .connect()
          .then((status) => log('connected to mqtt: $status'))
          .catchError((dynamic error) => log('cannot connect to mqtt: $error'));
    }

    _mqtt.updates?.expand((it) => it)?.listen((event) {
      var p = event.payload as MqttPublishMessage;
      var payload = MqttPublishPayload.bytesToStringAsString(p.payload.message);
      var topic = event.topic;
      log('on-message: $topic -> $payload');
    });
  }

  void log(String str) => _logger.log('MqttServiceImpl::- $str');

  void _onDisconnected(MqttClientConnectionStatus connectionStatus) async {
    // if connected state are not disconnected
    if (connectionState.state != MqttConnectionState.disconnected) {
      log('Mqtt disconnected with unknown state: ${connectionStatus.state}');
      return;
    }

    // get a new broker url by calling lb
    var result = await _dio.get<Map<String, dynamic>>(_s.brokerLbUrl);
    var data = result.data['data'] as Map<String, dynamic>;
    var url = data['url'] as String;
    var port = data['wss_port'] as String;
    var newUrl = 'wss://$url:$port/mqtt';
    _s.brokerUrl = newUrl;
    try {
      __mqtt = getMqttClient(_s);
      await _mqtt.connect();
    } catch (e) {
      log('got error when reconnecting mqtt: $e');
    }
  }

  final Dio _dio;
  final Logger _logger;

  final MqttClient Function() _getClient;
  MqttClient __mqtt;
  final Storage _s;
  final _subscribedTopics = <String>[];

  MqttClient get _mqtt => __mqtt ??= _getClient();

  Future<bool> get _isConnected {
    if (_s.isRealtimeEnabled) {
      return Stream<bool>.periodic(const Duration(milliseconds: 300))
          .map((_) =>
              _mqtt.connectionStatus.state == MqttConnectionState.connected)
          .distinct()
          .firstWhere((it) => it == true);
    } else {
      return Future<bool>.value(false);
    }
  }

  Task<Either<QError, void>> _connected() =>
      Task<bool>(() => _isConnected).attempt().leftMapToQError();

  @override
  Task<Either<QError, void>> subscribe(String topic) => _connected()
      .andThen(Task.delay(
          () => catching(() => _mqtt.subscribe(topic, MqttQos.atLeastOnce))))
      .leftMapToQError();

  @override
  Task<Either<QError, void>> unsubscribe(String topic) => _connected()
      .andThen(Task.delay(() => catching(() => _mqtt.unsubscribe(topic))))
      .leftMapToQError();

  @override
  bool get isConnected =>
      _mqtt?.connectionStatus?.state == MqttConnectionState.connected ?? false;

  @override
  MqttClientConnectionStatus get connectionState => _mqtt?.connectionStatus;

  Stream<Notification> get _notification {
    return _mqtt
        ?.forTopic(TopicBuilder.notification(_s.token))
        ?.asyncMap<List<Notification>>((event) {
      var jsonPayload =
          jsonDecode(event.payload.toString()) as Map<String, dynamic>;
      var actionType = jsonPayload['action_topic'] as String;
      var payload = jsonPayload['payload'] as Map<String, dynamic>;
      var actorId = payload['actor']['id'] as String;
      var actorEmail = payload['actor']['email'] as String;
      var actorName = payload['actor']['name'] as String;

      if (actionType == 'delete_message') {
        var mPayload =
            payload['data']['deleted_messages'] as List<Map<String, dynamic>>;
        return mPayload
            .map((m) {
              var roomId = m['room_id'] as String;
              var uniqueIds = m['message_unique_ids'] as List<String>;
              return uniqueIds.map(
                (uniqueId) => Tuple2(int.parse(roomId), uniqueId),
              );
            })
            .expand((it) => it)
            .map(
              (tuple) => Notification.message_deleted(
                actorId: actorId,
                actorEmail: actorEmail,
                actorName: actorName,
                roomId: tuple.value1,
                messageUniqueId: tuple.value2,
              ),
            )
            .toList();
      }

      if (actionType == 'clear_room') {
        var rooms_ =
            payload['data']['deleted_rooms'] as List<Map<String, dynamic>>;
        return rooms_.map((r) {
          return Notification.room_cleared(
            actorId: actorId,
            actorEmail: actorEmail,
            actorName: actorName,
            roomId: r['id'] as int,
          );
        }).toList();
      }

      return [];
    })?.expand((it) => it);
  }

  @override
  Either<QError, void> publishPresence({
    bool isOnline,
    DateTime lastSeen,
    String userId,
  }) {
    var millis = lastSeen.millisecondsSinceEpoch;
    var payload = isOnline ? '1' : '0';
    return _mqtt?.publish(TopicBuilder.presence(userId), '$payload:$millis');
  }

  @override
  Either<QError, void> publishTyping({
    bool isTyping,
    String userId,
    int roomId,
  }) {
    return _mqtt?.publishEvent(MqttTypingEvent(
      roomId: roomId.toString(),
      userId: userId,
      isTyping: isTyping,
    ));
  }

  @override
  Stream<MessageReceivedResponse> subscribeChannelMessage({String uniqueId}) {
    return _mqtt
        ?.forTopic(TopicBuilder.channelMessageNew('', uniqueId))
        ?.asyncMap((event) {
      // appId/channelId/c;
      var messageData = event.payload.toString();
      var messageJson = jsonDecode(messageData) as Map<String, dynamic>;
      var response = MessageReceivedResponse.fromJson(messageJson);

      return response;
    });
  }

  @override
  Stream<MessageDeletedResponse> subscribeMessageDeleted() {
    return _notification
        .asyncMap(
          (notification) => notification.join(
            (message) => message.toResponse(),
            (_) => MessageDeletedResponse(),
          ),
        )
        .where((it) => it.messageUniqueId != null);
  }

  @override
  Stream<MessageDeliveryResponse> subscribeMessageDelivered({int roomId}) {
    return _mqtt
        ?.forTopic(TopicBuilder.messageDelivered(roomId.toString()))
        ?.where((it) => int.parse(it.topic.split('/')[1]) == roomId)
        ?.asyncMap((msg) {
      // r/{roomId}/{roomId}/{userId}/d
      // {commentId}:{commentUniqueId}
      var payload = msg.payload.toString().split(':');
      var commentId = optionOf(payload[0]);
      var commentUniqueId = optionOf(payload[1]);
      return MessageDeliveryResponse(
        roomId: roomId,
        commentId: commentId.unwrap('commentId are null'),
        commentUniqueId: commentUniqueId.unwrap('commentUniqueId are null'),
      );
    });
  }

  @override
  Stream<MessageDeliveryResponse> subscribeMessageRead({int roomId}) {
    return _mqtt
        ?.subscribeEvent(MqttMessageReadEvent(
          roomId: roomId.toString(),
        ))
        ?.map((data) => MessageDeliveryResponse(
              commentId: data.id.toString(),
              roomId: data.chatRoomId.toNullable(),
              commentUniqueId: data.uniqueId.toNullable(),
            ));
  }

  @override
  Stream<Message> subscribeMessageReceived() async* {
    yield* _mqtt.subscribeEvent(MqttMessageReceivedEvent(token: _s.token));
  }

  @override
  Stream<RoomClearedResponse> subscribeRoomCleared() {
    return _notification
        .asyncMap(
          (notification) => notification.join(
            (message) => RoomClearedResponse(),
            (room) => room.toResponse(),
          ),
        )
        .where((res) => res.room_id != null);
  }

  @override
  Stream<UserPresenceResponse> subscribeUserPresence({
    @required String userId,
  }) async* {
    yield* _mqtt
        .subscribeEvent(MqttPresenceEvent(
          userId: userId,
        ))
        .map((data) => UserPresenceResponse(
              userId: data.userId,
              lastSeen: data.lastSeen,
              isOnline: data.isOnline,
            ));
  }

  @override
  Stream<UserTypingResponse> subscribeUserTyping({int roomId}) async* {
    // r/{roomId}/{roomId}/{userId}/t
    // 1
    yield* _mqtt
        .subscribeEvent(MqttTypingEvent(
          roomId: roomId.toString(),
          userId: '+',
        ))
        .map((data) => UserTypingResponse(
              roomId: data.roomId,
              userId: data.userId,
              isTyping: data.isTyping,
            ));
  }

  @override
  Either<QError, void> end() {
    return catching<void>(() {
      _subscribedTopics.forEach((topic) {
        var status = _mqtt.getSubscriptionsStatus(topic);
        if (status == MqttSubscriptionStatus.active) {
          _mqtt.unsubscribe(topic);
        }
      });
      _subscribedTopics.clear();
      _mqtt.disconnect();
    }).leftMapToQError();
  }

  @override
  Stream<void> onConnected() =>
      Stream<void>.periodic(const Duration(milliseconds: 300))
          .asyncMap((_) =>
              _mqtt.connectionStatus.state == MqttConnectionState.connected)
          .distinct()
          .where((it) => it == true);

  @override
  Stream<void> onDisconnected() =>
      Stream<void>.periodic(const Duration(milliseconds: 300))
          .asyncMap((_) =>
              _mqtt.connectionStatus.state == MqttConnectionState.disconnected)
          .distinct()
          .where((it) => it == true);

  @override
  Stream<void> onReconnecting() =>
      Stream<void>.periodic(const Duration(milliseconds: 300))
          .asyncMap((_) =>
              _mqtt.connectionStatus.state == MqttConnectionState.disconnecting)
          .distinct()
          .where((it) => it == true);

  @override
  Task<Either<QError, Unit>> synchronize([int lastMessageId]) {
    return Task.delay(() => left(QError('Not implemented')));
  }

  @override
  Task<Either<QError, Unit>> synchronizeEvent([String lastEventId]) {
    return Task.delay(() => left(QError('Not implemented')));
  }

  @override
  Either<QError, void> publishCustomEvent({
    int roomId,
    Map<String, dynamic> payload,
  }) {
    return _mqtt
        .publishEvent(MqttCustomEvent(roomId: roomId, payload: payload));
  }

  @override
  Stream<CustomEventResponse> subscribeCustomEvent({int roomId}) async* {
    yield* _mqtt.subscribeEvent(MqttCustomEvent(roomId: roomId));
  }
}

abstract class TopicBuilder {
  static String typing(String roomId, String userId) =>
      'r/$roomId/$roomId/$userId/t';

  static String presence(String userId) => 'u/$userId/s';

  static String messageDelivered(String roomId) => 'r/$roomId/+/+/d';

  static String notification(String token) => '$token/n';

  static String messageRead(String roomId) => 'r/$roomId/+/+/r';

  static String messageNew(String token) => '$token/c';

  static String channelMessageNew(String appId, String channelId) =>
      '$appId/$channelId/c';

  static String customEvent(int roomId) => 'r/$roomId/$roomId/e';
}

// region Json payload for notification
/*
{
  "action_topic": "delete_message",
  "payload": {
    "actor": {
      "id": "user id",
      "email": "user email",
      "name": "user name"
    },
    "data": {
      "is_hard_delete": true,
      "deleted_messages": [
        {
          "room_id": "room id",
          "message_unique_ids": ["abc", "hajjes"]
        }
      ]
    }
  }
}
{
  "action_topic": "clear_room",
  "payload": {
    "actor": {
      "id": "user id",
      "email": "user email",
      "name": "user name"
    },
    "data": {
      "deleted_rooms": [
        {
           "avatar_url": "https://qiscuss3.s3.amazonaws.com/uploads/55c0c6ee486be6b686d52e5b9bbedbbf/2.png",
           "chat_type": "single",
           "id": 80,
           "id_str": "80",
           "options": {},
           "raw_room_name": "asasmoyo@outlook.com kotak@outlook.com",
           "room_name": "kotak",
           "unique_id": "72058999c5d64c61bca7deed53963aa1",
           "last_comment": null
        }
      ]
    }
  }
}
*/
// endregion

@sealed
class Notification extends Union2Impl<MessageDeleted, RoomCleared> {
  Notification._(Union2<MessageDeleted, RoomCleared> union) : super(union);

  static final Doublet<MessageDeleted, RoomCleared> _factory =
      const Doublet<MessageDeleted, RoomCleared>();

  factory Notification.message_deleted({
    String actorId,
    String actorEmail,
    String actorName,
    int roomId,
    String messageUniqueId,
  }) {
    return Notification._(_factory.first(MessageDeleted(
      actorId: actorId,
      actorName: actorName,
      actorEmail: actorEmail,
      roomId: roomId,
      messageUniqueId: messageUniqueId,
    )));
  }

  factory Notification.room_cleared({
    String actorId,
    String actorEmail,
    String actorName,
    int roomId,
  }) =>
      Notification._(_factory.second(RoomCleared(
        actorId: actorId,
        actorEmail: actorEmail,
        actorName: actorName,
        roomId: roomId,
      )));
}

@sealed
class MessageDeleted {
  final String actorId, actorEmail, actorName, messageUniqueId;
  final int roomId;

  MessageDeleted({
    this.actorId,
    this.actorEmail,
    this.actorName,
    this.messageUniqueId,
    this.roomId,
  });

  MessageDeletedResponse toResponse() => MessageDeletedResponse(
        actorId: actorId,
        actorEmail: actorEmail,
        actorName: actorName,
        messageRoomId: roomId,
        messageUniqueId: messageUniqueId,
      );
}

@sealed
class RoomCleared {
  final String actorId, actorEmail, actorName;
  final int roomId;

  RoomCleared({
    this.actorId,
    this.actorEmail,
    this.actorName,
    this.roomId,
  });

  RoomClearedResponse toResponse() => RoomClearedResponse(room_id: roomId);
}
