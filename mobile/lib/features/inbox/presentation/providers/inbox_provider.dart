import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/features/inbox/data/inbox_repository.dart';

class InboxState {
  final List<ConversationModel> conversations;
  final bool isLoading;

  const InboxState({this.conversations = const [], this.isLoading = false});

  InboxState copyWith({List<ConversationModel>? conversations, bool? isLoading}) {
    return InboxState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class InboxNotifier extends StateNotifier<InboxState> {
  final InboxRepository _repository;

  InboxNotifier(this._repository) : super(const InboxState());

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    try {
      final conversations = await _repository.getConversations();
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;

  const ChatState({this.messages = const [], this.isLoading = false});

  ChatState copyWith({List<MessageModel>? messages, bool? isLoading}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final InboxRepository _repository;
  final String conversationId;
  Timer? _pollTimer;

  ChatNotifier(this._repository, this.conversationId) : super(const ChatState());

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _repository.getMessages(conversationId);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => loadMessages());
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> sendMessage(String content) async {
    try {
      final message = await _repository.sendMessage(conversationId, content);
      state = state.copyWith(messages: [...state.messages, message]);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final inboxProvider = StateNotifierProvider<InboxNotifier, InboxState>((ref) {
  return InboxNotifier(InboxRepository());
});

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) {
    final notifier = ChatNotifier(InboxRepository(), conversationId);
    notifier.loadMessages();
    notifier.startPolling();
    return notifier;
  },
);
