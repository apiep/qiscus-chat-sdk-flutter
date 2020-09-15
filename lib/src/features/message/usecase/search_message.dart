part of qiscus_chat_sdk.usecase.message;

class SearchMessageUseCase
    extends UseCase<MessageRepository, Stream<Message>, SearchMessageParams> {
  SearchMessageUseCase(MessageRepository repo) : super(repo);

  @override
  Task<Either<QError, Stream<Message>>> call(params) {
    return repository.searchMessage(
      query: params.query,
      roomIds: params.roomIds,
      userId: params.userId,
      type: params.type,
      roomType: params.roomType,
      page: params.page,
      limit: params.limit,
    );
  }
}

class SearchMessageParams extends Equatable {
  const SearchMessageParams({
    this.query,
    this.roomIds,
    this.fileType,
    this.page,
    this.limit,
    this.userId,
    this.type,
    this.roomType,
  });

  final List<int> roomIds;
  final String query;
  final String fileType;
  final int page;
  final int limit;
  final String userId;
  final List<String> type;
  final QRoomType roomType;

  @override
  List<Object> get props => [];
}
