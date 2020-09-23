part of qiscus_chat_sdk.core;

/// A helper mixin for handling subscription based
/// usecase, please ensure [params] implement
/// both == equality method and hashCode
mixin SubscriptionMixin<Service extends IRealtimeService,
    Params extends EquatableMixin, Response> {
  final _controller = StreamController<Response>.broadcast();
  final _subscriptions = HashMap<Params, StreamSubscription<Response>>();

  final streams = HashSet<Tuple2<Params, Stream<Response>>>();

  Service get repository;
  Stream<Response> mapStream(Params p);
  Option<String> topic(Params p);

  Stream<Response> get _stream => _controller.stream;
  Stream<Response> _createStream(Params param) async* {
    final controller = StreamController<Response>.broadcast(
      onListen: () {},
      onCancel: () {},
    );

    yield* controller.stream;

    yield* topic(param).fold(() async* {
      yield* Stream<Response>.empty();
    }, (t) async* {
      await repository.subscribe(t).run();
    });
    yield* mapStream(param);
  }

  Stream<Response> controllerFor(Params param) {
    return streams //
        .getWhere((it) => it.value1 == param)
        .map((it) => it.value2)
        .getOrElse(() => _createStream(param));
  }

  Task<void> unsubscribe(Params params) {
    var t1 = topic(params).map((_) => repository.unsubscribe(_));
    var t2 = t1.map(
      (_) => _.andThen(Task(() {
        var subscription = _subscriptions[params];
        return subscription?.cancel();
      })),
    );

    return t2.getOrElse(() => Task.delay(() {}));
  }

  Task<Stream<Response>> subscribe(Params params) {
    var listen = () {
      var stream = mapStream(params);
      var subscription = stream.listen((it) => _controller.sink.add(it));
      return subscription;
    };
    var listenTask = Task(() async => listen());
    var putIfAbsent = Task(
      () async => _subscriptions.putIfAbsent(params, listen),
    );
    var orIfEmpty = () => topic(params)
        .map((topic) => repository.subscribe(topic))
        .map((_) => _.andThen(putIfAbsent));
    return _subscriptions
        .getValue(params)
        .map((it) => Task.delay(() => it))
        .orElse(orIfEmpty)
        .map((_) => _.map((_) => _stream))
        .getOrElse(() => listenTask.andThen(
              Task(() async => _stream),
            ));
  }

  Task<StreamSubscription<Response>> listen(
    void Function(Response) onResponse, {
    Function onError,
    bool cancelOnError,
    void Function() onDone,
  }) {
    return Task(() async {
      return _stream.listen(
        onResponse,
        onError: onError,
        cancelOnError: cancelOnError,
        onDone: onDone,
      );
    });
  }
}

extension HashMapX<Key, Value> on HashMap<Key, Value> {
  Option<Value> getValue(Key key) {
    return optionOf(this[key]);
  }
}

extension HashSetX<T> on HashSet<T> {
  Option<T> getWhere(bool Function(T) func) {
    return optionOf(firstWhere(func));
  }
}
