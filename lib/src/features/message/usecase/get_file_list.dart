part of qiscus_chat_sdk.usecase.message;

class GetFileListUseCase
    extends UseCase<MessageRepository, Stream<Message>, GetFileListParams> {
  GetFileListUseCase(MessageRepository repo) : super(repo);

  @override
  Task<Either<QError, Stream<Message>>> call(params) {
    return repository.getFileList(
      roomIds: params.roomIds,
      fileType: params.fileType,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetFileListParams {
  final List<int> roomIds;
  final String fileType;
  final int page;
  final int limit;

  const GetFileListParams({
    this.roomIds,
    this.fileType,
    this.page,
    this.limit,
  });
}

Stream<QMessage> getFileListUseCase(
  Dio dio, {
  List<int> roomIds,
  String fileType,
  int page,
  int limit,
}) async* {
  final request = GetFileListRequest(
    roomIds: roomIds,
    fileType: fileType,
    page: page,
    limit: limit,
  );
  final messages = await dio.sendApiRequest(request).then(request.format);

  await for (var m in messages) {
    yield m.toModel();
  }
}
