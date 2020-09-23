part of qiscus_chat_sdk.usecase.realtime;

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

    if (_s.isRealtimeEnabled) connect();

    _mqtt.updates?.expand((it) => it)?.listen((event) {
      var p = event.payload as MqttPublishMessage;
      var payload = MqttPublishPayload.bytesToStringAsString(p.payload.message);
      var topic = event.topic;
      log('on-message: $topic -> $payload');
    });
  }

  Future<void> connect() async {
    try {
      var status = await _mqtt.connect();
      log('connected to mqtt: $status');
    } on Exception catch (error) {
      log('cannot connect to mqtt: $error');
    }
  }

  void log(String str) => _logger.log('MqttServiceImpl::- $str');

  void _onDisconnected(MqttClientConnectionStatus connectionStatus) async {
    // if connected state are not disconnected
    if (connectionState.state != MqttConnectionState.disconnected) {
      log('Mqtt disconnected with unknown state: ${connectionStatus.state}');
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    // get a new broker url by calling lb
    var result = await _dio.get<Map<String, dynamic>>(_s.brokerLbUrl);
    var data = result.data['data'] as Map<String, dynamic>;
    var url = data['url'] as String;
    var port = data['wss_port'] as String;
    var newUrl = 'wss://$url:$port/mqtt';
    _s.brokerUrl = newUrl;
    try {
      __mqtt = _getClient();
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
  Option<MqttClient> get mqtt => optionOf(_mqtt);

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

  Stream<Notification> notification() async* {
    var stream = optionOf(_mqtt)
        .map((it) => it.forTopic(TopicBuilder.notification(_s.token)));
    // var stream = _mqtt?.forTopic(TopicBuilder.notification(_s.token));
    await for (var event in stream.stream()) {
      var json = decodeJson(event.payload.toString());
      yield* json.fold(() async* {
        yield* Stream.empty();
      }, (json) async* {
        //
        var actionType = json['action_topic'] as String;
        var payload = json['payload'] as Map<String, dynamic>;

        if (actionType == 'delete_message') yield* parseMessageDeleted(payload);
      });
    }
  }

  Stream<Notification> parseClearRoom(Map<String, dynamic> payload) async* {
    var rooms = (payload['data']['deleted_rooms'] as List);
    rooms = rooms.cast<Map<String, dynamic>>();

    for (var room in rooms) {
      yield Notification.room_cleared(roomId: room['id'] as int);
    }
  }

  Stream<Notification> parseMessageDeleted(
    Map<String, dynamic> payload,
  ) async* {
    var actionPayload = (payload['data']['deleted_messages'] as List)
        .cast<Map<String, dynamic>>();

    for (var m in actionPayload) {
      var roomId = m['room_id'] as String;
      var uniqueIds = (m['message_unique_ids'] as List).cast<String>();
      for (var id in uniqueIds) {
        yield Notification.message_deleted(
          roomId: int.parse(roomId),
          messageUniqueId: id,
        );
      }
    }
  }

  Stream<Notification> get _notification => notification();

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
  Stream<Message> subscribeChannelMessage({String uniqueId}) async* {
    var stream = mqtt.map(
      (it) => it.forTopic(TopicBuilder.channelMessageNew('', uniqueId)),
    );

    await for (var event in stream.stream()) {
      var json = decodeJson(event.payload.toString());
      yield* json.foldAsStream((data) => Stream.value(Message.fromJson(data)));
    }
  }

  @override
  Stream<Message> subscribeMessageDeleted() {
    return _notification
        .asyncMap(
          (notification) => notification.join(
            (message) => Message(
              uniqueId: some(message.messageUniqueId),
              chatRoomId: some(message.roomId),
            ),
            (_) => null,
          ),
        )
        .where((it) => it != null);
  }

  @override
  Stream<Message> subscribeMessageDelivered({int roomId}) {
    return _mqtt
        ?.forTopic(TopicBuilder.messageDelivered(roomId.toString()))
        ?.where((it) => int.parse(it.topic.split('/')[1]) == roomId)
        ?.asyncMap((msg) {
      // r/{roomId}/{roomId}/{userId}/d
      // {commentId}:{commentUniqueId}
      var payload = msg.payload.toString().split(':');
      var commentId = optionOf(payload[0]);
      var commentUniqueId = optionOf(payload[1]);
      var userId = optionOf(msg.topic.split('/')[3]);
      var roomId = optionOf(msg.topic.split('/')[1]);

      return Message(
        id: commentId.map((a) => int.parse(a)),
        uniqueId: commentUniqueId,
        sender: some(User(
          id: userId,
        )),
        chatRoomId: roomId.map(int.parse),
      );
    });
  }

  @override
  Stream<Message> subscribeMessageRead({int roomId}) {
    return _mqtt?.subscribeEvent(MqttMessageReadEvent(
      roomId: roomId.toString(),
    ));
  }

  @override
  Stream<Message> subscribeMessageReceived() async* {
    yield* _mqtt.subscribeEvent(MqttMessageReceivedEvent(token: _s.token));
  }

  @override
  Stream<ChatRoom> subscribeRoomCleared() {
    return _notification
        .asyncMap(
          (notification) => notification.join(
            (message) => null,
            (room) => ChatRoom(
              id: some(room.roomId),
            ),
          ),
        )
        .where((it) => it != null);
  }

  @override
  Stream<UserPresence> subscribeUserPresence({
    @required String userId,
  }) async* {
    yield* _mqtt.subscribeEvent(MqttPresenceEvent(
      userId: userId,
    ));
  }

  @override
  Stream<UserTyping> subscribeUserTyping({int roomId}) async* {
    yield* _mqtt.subscribeEvent(MqttTypingEvent(
      roomId: roomId.toString(),
      userId: '+',
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
          .where((it) => it == true)
          .asBroadcastStream();

  @override
  Stream<void> onDisconnected() =>
      Stream<void>.periodic(const Duration(milliseconds: 300))
          .asyncMap((_) =>
              _mqtt.connectionStatus.state == MqttConnectionState.disconnected)
          .distinct()
          .where((it) => it == true)
          .asBroadcastStream();

  @override
  Stream<void> onReconnecting() =>
      Stream<void>.periodic(const Duration(milliseconds: 300))
          .asyncMap((_) =>
              _mqtt.connectionStatus.state == MqttConnectionState.disconnecting)
          .distinct()
          .where((it) => it == true)
          .asBroadcastStream();

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
    return _mqtt.publishEvent(MqttCustomEvent(
      roomId: roomId,
      payload: payload,
    ));
  }

  @override
  Stream<CustomEvent> subscribeCustomEvent({int roomId}) async* {
    yield* _mqtt.subscribeEvent(MqttCustomEvent(roomId: roomId, payload: null));
  }
}

@sealed
class Notification extends Union2Impl<MessageDeleted, RoomCleared> {
  Notification._(Union2<MessageDeleted, RoomCleared> union) : super(union);

  static final Doublet<MessageDeleted, RoomCleared> _factory =
      const Doublet<MessageDeleted, RoomCleared>();

  factory Notification.message_deleted({
    int roomId,
    String messageUniqueId,
  }) {
    return Notification._(_factory.first(MessageDeleted(
      roomId: roomId,
      messageUniqueId: messageUniqueId,
    )));
  }

  factory Notification.room_cleared({
    int roomId,
  }) =>
      Notification._(_factory.second(RoomCleared(
        roomId: roomId,
      )));
}

@sealed
class MessageDeleted {
  final String messageUniqueId;
  final int roomId;

  MessageDeleted({
    this.messageUniqueId,
    this.roomId,
  });

  MessageDeletedEvent toResponse() => MessageDeletedEvent(
        roomId: roomId,
        messageUniqueId: messageUniqueId,
      );
}

@sealed
class RoomCleared {
  final int roomId;

  RoomCleared({
    this.roomId,
  });

  ChatRoom toResponse() => ChatRoom(id: some(roomId));
}

extension OptionStreamX<Value> on Option<Stream<Value>> {
  Stream<Value> stream() async* {
    yield* fold(() async* {
      yield* Stream<Value>.empty();
    }, (value) async* {
      yield* value;
    });
  }
}

extension OptionX<Value> on Option<Value> {
  Stream<Output> foldAsStream<Output>(
    Stream<Output> Function(Value) func,
  ) async* {
    yield* fold(() async* {
      yield Stream<Value>.empty();
    }, (value) async* {
      yield value;
    });
  }
}
