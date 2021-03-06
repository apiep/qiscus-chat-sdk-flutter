import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';
import 'package:qiscus_chat_sdk/src/core/core.dart';
import 'package:qiscus_chat_sdk/src/features/message/entity.dart';

abstract class MessageRepository {
  Task<Either<QError, SendMessageResponse>> sendMessage(
    int roomId,
    String message, {
    String type = 'text',
    String uniqueId,
    Map<String, dynamic> extras,
    Map<String, dynamic> payload,
  });

  Task<Either<QError, GetMessageListResponse>> getMessages(
    int roomId,
    int lastMessageId, {
    bool after,
    int limit,
  });

  Task<Either<QError, Unit>> updateStatus({
    int roomId,
    int readId,
    int deliveredId,
  });

  Task<Either<QError, List<Message>>> deleteMessages({
    @required List<String> uniqueIds,
    bool isForEveryone = true,
    bool isHard = true,
  });
}

class GetMessageListResponse {
  const GetMessageListResponse(this.messages);

  final List<Map<String, dynamic>> messages;
}

class SendMessageResponse {
  const SendMessageResponse(this.comment);
  final Map<String, dynamic> comment;
}
