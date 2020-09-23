part of qiscus_chat_sdk.usecase.realtime;

class SyncServiceImpl implements IRealtimeService {
  SyncServiceImpl({
    @required this.storage,
    @required this.interval,
    @required this.logger,
    @required this.dio,
  });

  final Dio dio;
  final Logger logger;
  final Storage storage;
  final Interval interval;

  int get _messageId => storage.lastMessageId ?? 0;

  int get _eventId => storage.lastEventId ?? 0;

  void log(String str) => logger.log('SyncServiceImpl::- $str');

  // region Producer
  Stream<RealtimeEvent> syncEvent$(Stream<void> interval) async* {
    await for (var _ in interval) {
      var request = SynchronizeEventRequest(lastEventId: _eventId);
      var r = await dio.sendApiRequest(request).then(request.format);
      log('QiscusSyncAdapter: synchronize-event');
      yield* Stream.fromIterable(r.value2);
    }
  }

  // Stream<RealtimeEvent> get _syncEvent$ => _interval$
  //     .map((_) {
  //       var request = SynchronizeEventRequest(lastEventId: _eventId);
  //       return dio
  //           .sendApiRequest(request)
  //           .then((r) => request.format(r))
  //           .asStream();
  //     })
  //     .flatten()
  //     .tap((_) => log('QiscusSyncAdapter: synchronize-event'))
  //     .map((data) => data.value2)
  //     .expand(id)
  //     .asBroadcastStream();
  Stream<RealtimeEvent> get _syncEvent$ =>
      syncEvent$(_interval$).asBroadcastStream();

  Stream<Message> sync$(Stream<void> interval) async* {
    await for (var _ in interval) {
      var request = SynchronizeRequest(lastMessageId: _messageId);
      var r = await dio.sendApiRequest(request).then(request.format);

      if (r.value1 > storage.lastMessageId) {
        storage.lastMessageId = r.value1;
      }

      log('QiscusSyncAdapter: synchronize');

      yield* Stream.fromIterable(r.value2);
    }
  }

  // Stream<Message> get _sync$ => _interval$
  //     .map((_) {
  //       var request = SynchronizeRequest(lastMessageId: _messageId);
  //       return dio
  //           .sendApiRequest(request)
  //           .then((r) => request.format(r))
  //           .asStream();
  //     })
  //     .flatten()
  //     .tap((res) {
  //       if (res.value1 > storage.lastMessageId) {
  //         storage.lastMessageId = res.value1;
  //       }
  //     })
  //     .tap((_) => log('QiscusSyncAdapter: synchronize'))
  //     .map((it) => it.value2)
  //     .expand(id)
  //     .asBroadcastStream();
  Stream<Message> get _sync$ => sync$(_interval$).asBroadcastStream();

  Stream<MessageReadEvent> get _messageRead$ => _syncEvent$ //
      .where((event) => event is MessageReadEvent)
      .cast<MessageReadEvent>();
  Stream<MessageDeliveredEvent> get _messageDelivered$ => _syncEvent$ //
      .where((event) => event is MessageDeliveredEvent)
      .cast<MessageDeliveredEvent>();
  Stream<MessageDeletedEvent> get _messageDeleted$ => _syncEvent$ //
      .where((event) => event is MessageDeletedEvent)
      .cast<MessageDeletedEvent>();
  Stream<RoomClearedEvent> get _roomCleared$ => _syncEvent$ //
      .where((event) => event is RoomClearedEvent)
      .cast<RoomClearedEvent>();
  // endregion

  @override
  Stream<Message> subscribeMessageRead({int roomId}) {
    return _messageRead$.asyncMap((event) => Message(
          id: event.messageId.toOption(),
          uniqueId: event.messageUniqueId.toOption(),
          chatRoomId: event.roomId.toOption(),
          sender: some(User(
            id: event.userId.toOption(),
          )),
        ));
  }

  @override
  Stream<Message> subscribeMessageReceived({int roomId}) {
    return _synchronize(() => storage.lastMessageId);
  }

  @override
  Stream<ChatRoom> subscribeRoomCleared() {
    return _roomCleared$.map((event) => ChatRoom(
          id: event.roomId.toOption(),
        ));
  }

  @override
  Task<Either<QError, Unit>> synchronize([int lastMessageId]) {
    return task(() async {
      var request = SynchronizeRequest(lastMessageId: lastMessageId);
      return dio.sendApiRequest(request).then(request.format);
    }).rightMap((_) => unit);
  }

  @override
  Task<Either<QError, Unit>> synchronizeEvent([String eventId]) {
    return task(() async {
      var request =
          SynchronizeEventRequest(lastEventId: int.tryParse(eventId) ?? 0);
      return dio.sendApiRequest(request).then(request.format);
    }).rightMap((_) => unit);
  }

  Stream<Message> _synchronize([
    int Function() getMessageId,
  ]) {
    return _sync$;
  }

  @override
  bool get isConnected => true;

  @override
  MqttClientConnectionStatus get connectionState => null;

  Stream<Unit> get _interval$ => interval.interval();

  // region Not implemented on sync adapter

  @override
  Stream<Message> subscribeChannelMessage({String uniqueId}) {
    return Stream.empty();
  }

  @override
  Stream<Message> subscribeMessageDeleted() {
    return _messageDeleted$.map((event) => Message(
          chatRoomId: event.roomId.toOption(),
          uniqueId: event.messageUniqueId.toOption(),
        ));
  }

  @override
  Stream<Message> subscribeMessageDelivered({int roomId}) {
    return _messageDelivered$.map((event) {
      return Message(
        chatRoomId: event.roomId.toOption(),
        id: event.messageId.toOption(),
        uniqueId: event.messageUniqueId.toOption(),
        sender: User(id: event.userId.toOption()).toOption(),
      );
    });
  }

  @override
  Stream<UserPresence> subscribeUserPresence({String userId}) {
    return Stream.empty();
  }

  @override
  Task<Either<QError, void>> subscribe(String topic) =>
      Task.delay(() => left(QError('Not supported')));

  @override
  Stream<UserTyping> subscribeUserTyping({String userId, int roomId}) {
    return Stream.empty();
  }

  @override
  Either<QError, void> publishPresence({
    bool isOnline,
    DateTime lastSeen,
    String userId,
  }) {
    return left(QError('Not available for this service'));
  }

  @override
  Either<QError, void> publishTyping({
    bool isTyping,
    String userId,
    int roomId,
  }) {
    return left(QError('Not available for this service'));
  }

  @override
  Either<QError, void> end() {
    interval.stop();
    return right(null);
  }

  @override
  Stream<void> onConnected() => Stream.empty();

  @override
  Stream<void> onDisconnected() => Stream.empty();

  @override
  Stream<void> onReconnecting() => Stream.empty();

  @override
  Stream<CustomEvent> subscribeCustomEvent({int roomId}) => Stream.empty();

  @override
  Either<QError, void> publishCustomEvent({
    int roomId,
    Map<String, dynamic> payload,
  }) {
    return left<QError, void>(QError('Not implemented'));
  }

  @override
  Task<Either<QError, void>> unsubscribe(String topic) =>
      Task.delay(() => left<QError, void>(QError('Not implemented')));
// endregion
}
