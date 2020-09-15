part of qiscus_chat_sdk.usecase.message;

class SendMessageRequest extends IApiRequest<Message> {
  final int roomId;
  final String message;
  final String type;
  final String uniqueId;
  final Map<String, dynamic> extras;
  final Map<String, dynamic> payload;

  SendMessageRequest({
    @required this.roomId,
    @required this.message,
    this.uniqueId,
    this.type = 'text',
    this.extras,
    this.payload,
  });

  String get url => 'post_comment';
  IRequestMethod get method => IRequestMethod.post;
  Map<String, dynamic> get body => <String, dynamic>{
        'topic_id': roomId.toString(),
        'comment': message,
        'type': type,
        'unique_temp_id': uniqueId,
        'payload': payload,
        'extras': extras,
      };

  Message format(Map<String, dynamic> json) {
    var data = json['results']['comment'] as Map<String, dynamic>;
    return Message.fromJson(data);
  }
}

class GetMessagesRequest extends IApiRequest<List<Message>> {
  final int roomId;
  final int lastMessageId;
  final int limit;
  final bool after;

  GetMessagesRequest({
    @required this.roomId,
    @required this.lastMessageId,
    this.after = false,
    this.limit = 20,
  });

  String get url => 'load_comments';
  IRequestMethod get method => IRequestMethod.get;
  Map<String, dynamic> get params => <String, dynamic>{
        'topic_id': roomId,
        'last_comment_id': lastMessageId,
        'after': after,
        'limit': limit,
      };

  List<Message> format(Map<String, dynamic> json) {
    var data = (json['results']['comments'] as List) //
        .cast<Map<String, dynamic>>();

    return data.map((it) => Message.fromJson(it)).toList();
  }
}

class UpdateMessageStatusRequest extends IApiRequest<Unit> {
  final int roomId;
  final int lastReadId;
  final int lastDeliveredId;

  UpdateMessageStatusRequest({
    @required this.roomId,
    this.lastReadId,
    this.lastDeliveredId,
  });

  String get url => 'update_comment_status';
  IRequestMethod get method => IRequestMethod.post;
  Map<String, dynamic> get body => <String, dynamic>{
        'room_id': roomId.toString(),
        'last_comment_read_id': lastReadId?.toString(),
        'last_comment_received_id': lastDeliveredId?.toString(),
      };

  format(json) {
    return unit;
  }
}

UpdateMessageStatusRequest markMessageAsRead({
  @required int roomId,
  @required int messageId,
}) {
  return UpdateMessageStatusRequest(
    roomId: roomId,
    lastReadId: messageId,
  );
}

UpdateMessageStatusRequest markMessageAsDelivered({
  @required int roomId,
  @required int messageId,
}) {
  return UpdateMessageStatusRequest(
    roomId: roomId,
    lastDeliveredId: messageId,
  );
}

class DeleteMessagesRequest extends IApiRequest<List<Message>> {
  final List<String> uniqueIds;
  final bool isHardDelete;
  final bool isForEveryone;
  DeleteMessagesRequest({
    @required this.uniqueIds,
    this.isForEveryone = true,
    this.isHardDelete = true,
  });

  get url => 'delete_messages';
  get method => IRequestMethod.delete;
  get params => <String, dynamic>{
        'unique_ids': uniqueIds,
        'is_hard_delete': isHardDelete,
        'is_delete_for_everyone': isForEveryone,
      };
  format(json) {
    var data = (json['results']['comments'] as List) //
        .cast<Map<String, dynamic>>();

    return data.map((m) => Message.fromJson(m)).toList();
  }
}

class GetFileListRequest extends IApiRequest<Stream<Message>> {
  GetFileListRequest({
    this.roomIds,
    this.fileType,
    this.page,
    this.limit,
  });

  final List<int> roomIds;
  final String fileType;
  final int page, limit;

  get url => 'file_list';
  get method => IRequestMethod.post;
  get body => <String, dynamic>{
        'room_ids': roomIds?.map((it) => it.toString()),
        'file_type': fileType,
        'page': page,
        'limit': limit,
      };

  Stream<Message> format(json) async* {
    var data =
        (json['results']['comments'] as List).cast<Map<String, dynamic>>();

    for (var c in data) {
      yield Message.fromJson(c);
    }
  }
}

class SearchMessageRequest extends IApiRequest<Stream<Message>> {
  SearchMessageRequest({
    this.query,
    this.roomIds,
    this.userId,
    this.type,
    this.roomType,
    this.page,
    this.limit,
  });

  final String query;
  final List<int> roomIds;
  final String userId;
  final List<String> type;
  final QRoomType roomType;
  final int page, limit;

  get url => 'search';
  get method => IRequestMethod.post;
  get body {
    final roomType = optionOf(this.roomType).map((type) {
      switch (type) {
        case QRoomType.single: return 'single';
        case QRoomType.group: return 'group';
        case QRoomType.channel: return 'group';
      }
    }).toNullable();
    final isPublic = optionOf(this.roomType).map((type) {
      switch (type) {
        case QRoomType.single: return false;
        case QRoomType.group: return false;
        case QRoomType.channel: return true;
      }
    }).toNullable();

    return <String, dynamic>{
      'query': query,
      'room_ids': roomIds,
      'sender': userId,
      'type': type,
      'room_type': roomType,
      'is_public': isPublic,
      'page': page,
      'limit': limit,
    };
  }

  Stream<Message> format(json) async* {
    final data = (json['results']['comments'] as List).cast<Map<String, dynamic>>();
    for (var c in data) {
      yield Message.fromJson(c);
    }
  }
}

