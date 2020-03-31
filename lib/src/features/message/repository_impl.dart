import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:qiscus_chat_sdk/src/core/extension.dart';
import 'package:qiscus_chat_sdk/src/features/message/repository.dart';

import 'api.dart';

class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl(this._api);

  final MessageApi _api;

  @override
  Task<Either<Exception, GetMessageListResponse>> getMessages(
    int roomId,
    int lastMessageId, {
    bool after = false,
    int limit = 20,
  }) {
    return Task(
      () => _api.loadComments(
        roomId,
        lastMessageId,
        limit: limit,
        after: after,
      ),
    ).attempt().leftMapToException().rightMap((str) {
      var json = jsonDecode(str);
      var messages = json['results']['comments'] //
          .cast<List>() //
          .cast<Map<String, dynamic>>();
      return GetMessageListResponse(messages);
    });
  }

  @override
  Task<Either<Exception, SendMessageResponse>> sendMessage(
    int roomId,
    String message, {
    String type = 'text',
    String uniqueId,
    Map<String, dynamic> extras,
    Map<String, dynamic> payload,
  }) {
    return Task(
      () => _api.submitComment(PostCommentRequest(
        roomId: roomId.toString(),
        text: message,
        type: type,
        uniqueId: uniqueId,
        extras: extras,
        payload: payload,
      )),
    ).attempt().leftMapToException().rightMap((str) {
      var json = jsonDecode(str);
      var comment = json['results']['comment'];
      return SendMessageResponse(comment);
    });
  }

  @override
  Task<Either<Exception, Unit>> updateStatus({
    int roomId,
    int readId = 0,
    int deliveredId = 0,
  }) {
    return Task(() => _api.updateStatus(UpdateStatusRequest(
          roomId: roomId,
          lastDeliveredId: deliveredId,
          lastReadId: readId,
        ))).attempt().rightMap((_) => unit);
  }
}