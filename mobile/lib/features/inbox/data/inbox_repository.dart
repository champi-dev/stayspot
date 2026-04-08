import 'package:stayspot/core/api_client.dart';

class InboxRepository {
  final ApiClient _api = ApiClient();

  Future<List<ConversationModel>> getConversations() async {
    final response = await _api.dio.get('/conversations');
    return (response.data['conversations'] as List)
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MessageModel>> getMessages(String conversationId, {int page = 1}) async {
    final response = await _api.dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'limit': 50},
    );
    return (response.data['messages'] as List)
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MessageModel> sendMessage(String conversationId, String content) async {
    final response = await _api.dio.post(
      '/conversations/$conversationId/messages',
      data: {'content': content},
    );
    return MessageModel.fromJson(response.data['message']);
  }

  Future<String> startConversation(String recipientId, String content) async {
    final response = await _api.dio.post('/conversations', data: {
      'recipientId': recipientId,
      'content': content,
    });
    return response.data['conversationId'] as String;
  }
}

class ConversationModel {
  final String id;
  final ConversationUser? otherUser;
  final LastMessage? lastMessage;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      otherUser: json['otherUser'] != null
          ? ConversationUser.fromJson(json['otherUser'] as Map<String, dynamic>)
          : null,
      lastMessage: json['lastMessage'] != null
          ? LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class ConversationUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  const ConversationUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName';

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class LastMessage {
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final bool isOwn;

  const LastMessage({
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.isOwn = false,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      isOwn: json['isOwn'] as bool? ?? false,
    );
  }
}

class MessageModel {
  final String id;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final MessageSender sender;

  const MessageModel({
    required this.id,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    required this.sender,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      sender: MessageSender.fromJson(json['sender'] as Map<String, dynamic>),
    );
  }
}

class MessageSender {
  final String id;
  final String firstName;
  final String lastName;

  const MessageSender({required this.id, required this.firstName, required this.lastName});

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
    );
  }
}
