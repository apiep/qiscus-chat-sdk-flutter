import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:qiscus_chat_sdk/src/core/core.dart';
import 'package:qiscus_chat_sdk/src/features/message/message.dart';
import 'package:qiscus_chat_sdk/src/features/room/room.dart';
import 'package:qiscus_chat_sdk/src/features/user/user.dart';

import 'src/core/utils.dart';
import 'src/qiscus_core.dart';

extension XQiscusSDK on QiscusSDK {
  Future<void> setup$(String appId) async {
    return futurify1((cb) {
      setup(appId, callback: cb);
    });
  }

  Future<void> setupWithCustomServer$(
    String appId, {
    String baseUrl = Storage.defaultBaseUrl,
    String brokerUrl = Storage.defaultBrokerUrl,
    String brokerLbUrl = Storage.defaultBrokerLbUrl,
    int syncInterval = Storage.defaultSyncInterval,
    int syncIntervalWhenConnected = Storage.defaultSyncIntervalWhenConnected,
  }) {
    return futurify1((cb) {
      setupWithCustomServer(
        appId,
        callback: cb,
        baseUrl: baseUrl,
        brokerUrl: brokerUrl,
        brokerLbUrl: brokerLbUrl,
        syncInterval: syncInterval,
        syncIntervalWhenConnected: syncIntervalWhenConnected,
      );
    });
  }

  Future<QAccount> updateUser$({
    String name,
    String avatarUrl,
    Map<String, dynamic> extras,
  }) async {
    return futurify2((cb) {
      updateUser(
        name: name,
        avatarUrl: avatarUrl,
        extras: extras,
        callback: cb,
      );
    });
  }

  Future<QAccount> setUser$({
    @required String userId,
    @required String userKey,
    String username,
    String avatarUrl,
    Map<String, dynamic> extras,
  }) async {
    return futurify2((cb) {
      setUser(
        userId: userId,
        userKey: userKey,
        callback: cb,
        username: username,
        avatarUrl: avatarUrl,
        extras: extras,
      );
    });
  }

  Future<List<QParticipant>> addParticipants$({
    @required int roomId,
    @required List<String> userIds,
  }) async {
    return futurify2((cb) {
      addParticipants(roomId: roomId, userIds: userIds, callback: cb);
    });
  }

  static Future<QiscusSDK> withAppId$(String appId) async {
    var qiscus = QiscusSDK();
    await qiscus.setup$(appId);
    return qiscus;
  }

  static Future<QiscusSDK> withCustomServer$(
    String appId, {
    String baseUrl = Storage.defaultBaseUrl,
    String brokerUrl = Storage.defaultBrokerUrl,
    String brokerLbUrl = Storage.defaultBrokerLbUrl,
    int syncInterval = Storage.defaultSyncInterval,
    int syncIntervalWhenConnected = Storage.defaultSyncIntervalWhenConnected,
  }) async {
    var qiscus = QiscusSDK();
    await qiscus.setupWithCustomServer$(
      appId,
      baseUrl: baseUrl,
      brokerUrl: brokerUrl,
      brokerLbUrl: brokerLbUrl,
      syncInterval: syncInterval,
      syncIntervalWhenConnected: syncIntervalWhenConnected,
    );
    return qiscus;
  }

  Future<QUser> blockUser$({@required String userId}) {
    return futurify2((cb) {
      blockUser(userId: userId, callback: cb);
    });
  }

  Future<QChatRoom> chatUser$({
    @required String userId,
    Map<String, dynamic> extras,
  }) async {
    return futurify2((cb) {
      chatUser(userId: userId, extras: extras, callback: cb);
    });
  }

  Future<void> clearMessagesByChatRoomId$({
    @required List<String> roomUniqueIds,
  }) async {
    return futurify1((cb) {
      clearMessagesByChatRoomId(roomUniqueIds: roomUniqueIds, callback: cb);
    });
  }

  Future<void> clearUser$() async {
    return futurify1((cb) {
      clearUser(callback: cb);
    });
  }

  Future<QChatRoom> createChannel$({
    @required String uniqueId,
    String name,
    String avatarUrl,
    Map<String, dynamic> extras,
  }) async {
    return futurify2((cb) {
      createChannel(
        uniqueId: uniqueId,
        callback: cb,
        name: name,
        avatarUrl: avatarUrl,
        extras: extras,
      );
    });
  }

  Future<QChatRoom> createGroupChat$({
    @required String name,
    @required List<String> userIds,
    String avatarUrl,
    Map<String, dynamic> extras,
  }) async {
    return futurify2((cb) {
      createGroupChat(
        name: name,
        userIds: userIds,
        callback: cb,
        avatarUrl: avatarUrl,
        extras: extras,
      );
    });
  }

  Future<List<QMessage>> deleteMessages$({
    @required List<String> messageUniqueIds,
  }) async {
    return futurify2((cb) {
      deleteMessages(messageUniqueIds: messageUniqueIds, callback: cb);
    });
  }

  Future<List<QChatRoom>> getAllChatRooms$({
    bool showParticipant,
    bool showRemoved,
    bool showEmpty,
    int limit,
    int page,
  }) async {
    return futurify2((cb) {
      getAllChatRooms(
        callback: cb,
        showParticipant: showParticipant,
        showRemoved: showRemoved,
        showEmpty: showEmpty,
        limit: limit,
        page: page,
      );
    });
  }

  Future<List<QUser>> getBlockedUsers$({
    int page,
    int limit,
  }) async {
    return futurify2((cb) {
      getBlockedUsers(callback: cb, page: page, limit: limit);
    });
  }

  Future<QAccount> setUserWithIdentityToken$({
    @required String token,
  }) {
    return futurify2((cb) {
      setUserWithIdentityToken(callback: cb, token: token);
    });
  }

  Future<QChatRoom> getChannel$({
    @required String uniqueId,
  }) async {
    return futurify2((cb) => getChannel(uniqueId: uniqueId, callback: cb));
  }

  Future<List<QChatRoom>> getChatRooms$({
    List<int> roomIds,
    List<String> uniqueIds,
    int page,
    bool showRemoved,
    bool showParticipants,
  }) async {
    return futurify2((cb) {
      getChatRooms(
        callback: cb,
        roomIds: roomIds,
        uniqueIds: uniqueIds,
        page: page,
        showRemoved: showRemoved,
        showParticipants: showParticipants,
      );
    });
  }

  Future<QChatRoomWithMessages> getChatRoomWithMessages$({
    @required int roomId,
  }) async {
    return futurify2((cb) {
      getChatRoomWithMessages(
          roomId: roomId,
          callback: (room, msgs, err) {
            cb(QChatRoomWithMessages(room, msgs), err);
          });
    });
  }

  Future<String> getJWTNonce$() {
    return futurify2((cb) => getJWTNonce(callback: cb));
  }

  Future<List<QMessage>> getNextMessagesById$({
    @required int roomId,
    @required int messageId,
    int limit,
  }) {
    return futurify2((cb) {
      getNextMessagesById(roomId: roomId, messageId: messageId, callback: cb);
    });
  }

  Future<List<QMessage>> getPreviousMessagesById$({
    @required int roomId,
    int limit,
    int messageId,
  }) async {
    return futurify2((cb) {
      getPreviousMessagesById(
        roomId: roomId,
        callback: cb,
        limit: limit,
        messageId: messageId,
      );
    });
  }

  Future<QAccount> getUserData$() async {
    return futurify2((cb) {
      getUserData(callback: cb);
    });
  }

  Future<List<String>> removeParticipants$({
    @required int roomId,
    @required List<String> userIds,
  }) async {
    return futurify2((cb) {
      removeParticipants(
        callback: cb,
        roomId: roomId,
        userIds: userIds,
      );
    });
  }

  Future<QMessage> sendMessage$({
    @required QMessage message,
  }) async {
    return futurify2((cb) {
      sendMessage(message: message, callback: cb);
    });
  }

  Future<List<QUser>> getUsers$({
    @deprecated String searchUsername,
    int page,
    int limit,
  }) async {
    return futurify2((cb) {
      getUsers(
        callback: cb,
        // ignore: deprecated_member_use_from_same_package
        searchUsername: searchUsername,
        page: page,
        limit: limit,
      );
    });
  }

  Future<void> markAsDelivered$({
    @required int roomId,
    @required int messageId,
  }) async {
    return futurify1((cb) {
      markAsDelivered(
        roomId: roomId,
        messageId: messageId,
        callback: cb,
      );
    });
  }

  Future<void> markAsRead$({
    @required int roomId,
    @required int messageId,
  }) async {
    return futurify1((cb) {
      markAsRead(
        roomId: roomId,
        messageId: messageId,
        callback: cb,
      );
    });
  }

  Stream<int> onChatRoomCleared$() async* {
    yield* streamify(onChatRoomCleared);
  }

  Stream<void> onConnected$() async* {
    yield* streamify((cb) {
      return onConnected(() => cb(null));
    });
  }

  Stream<void> onDisconnected$() async* {
    yield* streamify((cb) {
      return onDisconnected(() => cb(null));
    });
  }

  Stream<QMessage> onMessageReceived$() async* {
    yield* streamify(onMessageReceived);
  }

  Stream<QMessage> onMessageDeleted$() async* {
    yield* streamify(onMessageDeleted);
  }

  Stream<QMessage> onMessageDelivered$() async* {
    yield* streamify(onMessageDelivered);
  }

  Stream<QMessage> onMessageRead$() async* {
    yield* streamify(onMessageRead);
  }

  Stream<void> onReconnecting$() async* {
    yield* streamify((cb) => onReconnecting(() => cb(null)));
  }

  Stream<QUserPresence> onUserOnlinePresence$() async* {
    yield* streamify((cb) {
      return onUserOnlinePresence((userId, isOnline, lastOnline) {
        cb(
          QUserPresence()
            ..userId = userId
            ..isOnline = isOnline
            ..lastOnline = lastOnline,
        );
      });
    });
  }

  Stream<QUserTyping> onUserTyping$() async* {
    yield* streamify((cb) {
      return onUserTyping((userId, roomId, isTyping) {
        cb(
          QUserTyping()
            ..userId = userId
            ..roomId = roomId
            ..isTyping = isTyping,
        );
      });
    });
  }

  Future<String> upload$(File file) async {
    return futurify2((cb) {
      upload(
          file: file,
          callback: (error, _, url) {
            if (url != null) {
              cb(url, error);
            }
          });
    });
  }
}
