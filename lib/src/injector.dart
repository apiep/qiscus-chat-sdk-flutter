part of qiscus_chat_sdk;

@sealed
class Injector {
  final c = GetIt.asNewInstance();

  void singleton<T>(T Function() inst, [String name]) {
    c.registerLazySingleton<T>(inst, instanceName: name);
  }

  void factory_<T>(T Function() inst, [String name]) {
    c.registerFactory(inst, instanceName: name);
  }

  T resolve<T>([String name]) {
    return c.get<T>(instanceName: name);
  }

  T get<T>([String name]) {
    return resolve<T>(name);
  }

  void setup() {
    _configure();
  }

  void _configure() {
    // core
    singleton(() => Storage());
    factory_(() => Logger(resolve()));
    singleton<Dio>(() => getDio(resolve(), resolve()));
    factory_<MqttClient>(() => getMqttClient(resolve()));
    singleton(() => AppConfigRepository(dio: resolve()));
    singleton(() => AppConfigUseCase(resolve(), resolve()));

    // realtime
    singleton(() => MqttServiceImpl(
          () => resolve(),
          resolve(),
          resolve(),
          resolve(),
        ));
    singleton(() => Interval(
          resolve(),
          resolve<MqttServiceImpl>(),
        ));
    singleton(() => SyncServiceImpl(
          storage: resolve(),
          interval: resolve(),
          logger: resolve(),
          dio: resolve(),
        ));
    singleton<IRealtimeService>(() => RealtimeServiceImpl(
          resolve<MqttServiceImpl>(),
          resolve<SyncServiceImpl>(),
        ));
    singleton(() => OnConnected(resolve()));
    singleton(() => OnDisconnected(resolve()));
    singleton(() => OnReconnecting(resolve()));

    // room
    singleton<IRoomRepository>(() => RoomRepositoryImpl(
          dio: resolve(),
        ));
    factory_(() => ClearRoomMessagesUseCase(resolve()));
    factory_(() => CreateGroupChatUseCase(resolve()));
    factory_(() => GetRoomUseCase(resolve()));
    factory_(() => GetRoomByUserIdUseCase(resolve()));
    factory_(() => GetRoomInfoUseCase(resolve()));
    factory_(() => GetRoomWithMessagesUseCase(resolve()));
    factory_(() => GetAllRoomsUseCase(resolve()));
    factory_(() => GetTotalUnreadCountUseCase(resolve()));
    factory_(() => AddParticipantUseCase(resolve()));
    factory_(() => GetParticipantsUseCase(resolve()));
    factory_(() => RemoveParticipantUseCase(resolve()));
    factory_(() => UpdateRoomUseCase(resolve()));
    factory_(() => OnRoomMessagesCleared(resolve()));

    // user
    singleton<IUserRepository>(() => UserRepositoryImpl(resolve()));
    factory_(() => AuthenticateUserUseCase(
          resolve<IUserRepository>(),
          resolve(),
        ));
    factory_(() => AuthenticateUserWithTokenUseCase(
          resolve<IUserRepository>(),
          resolve(),
        ));
    factory_(() => BlockUserUseCase(resolve()));
    factory_(() => UnblockUserUseCase(resolve()));
    factory_(() => GetBlockedUserUseCase(resolve()));
    factory_(() => GetNonceUseCase(resolve()));
    factory_(() => GetUserDataUseCase(resolve()));
    factory_(() => GetUsersUseCase(resolve()));
    factory_(() => RegisterDeviceTokenUseCase(resolve()));
    factory_(() => UnregisterDeviceTokenUseCase(resolve()));
    factory_(() => UpdateUserUseCase(
          resolve(),
          resolve(),
        ));
    singleton(() => TypingUseCase(resolve()));
    singleton(() => PresenceUseCase(resolve()));

    // message
    singleton<MessageRepository>(() => MessageRepositoryImpl(resolve()));
    factory_(() => DeleteMessageUseCase(resolve()));
    factory_(() => GetMessageListUseCase(resolve()));
    factory_(() => SendMessageUseCase(resolve()));
    factory_(() => UpdateMessageStatusUseCase(resolve()));
    factory_(() => GetFileListUseCase(resolve()));
    factory_(() => SearchMessageUseCase(resolve()));
    singleton(() => OnMessageReceived(
          resolve(),
          resolve<UpdateMessageStatusUseCase>(),
        ));
    singleton(() => OnMessageDelivered(resolve()));
    singleton(() => OnMessageRead(resolve()));
    singleton(() => OnMessageDeleted(resolve()));
  }
}
