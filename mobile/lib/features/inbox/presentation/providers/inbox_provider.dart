import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/core/notifications_service.dart';
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
  final bool hostTyping;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hostTyping = false,
  });

  ChatState copyWith({List<MessageModel>? messages, bool? isLoading, bool? hostTyping}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hostTyping: hostTyping ?? this.hostTyping,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final InboxRepository _repository;
  final String conversationId;
  Timer? _pollTimer;
  String? _ownUserId;

  ChatNotifier(this._repository, this.conversationId) : super(const ChatState());

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.getMessages(conversationId);
      final previousIds = state.messages.map((m) => m.id).toSet();
      state = state.copyWith(
        messages: result.messages,
        isLoading: false,
        hostTyping: result.hostTyping,
      );
      // Notify about host messages that arrived while the app is backgrounded
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (previousIds.isNotEmpty && lifecycle != AppLifecycleState.resumed) {
        for (final m in result.messages) {
          if (!previousIds.contains(m.id) && m.sender.id != _ownUserId) {
            NotificationsService.instance
                .showHostMessage(m.sender.firstName, m.content);
          }
        }
      }
      // Poll fast while the host reply is generating so the typing
      // indicator and the reply itself feel live
      _setPollInterval(result.hostTyping
          ? const Duration(milliseconds: 1500)
          : const Duration(seconds: 5));
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Duration? _currentInterval;

  void _setPollInterval(Duration interval) {
    if (_currentInterval == interval) return;
    _currentInterval = interval;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => loadMessages());
  }

  void startPolling() {
    _setPollInterval(const Duration(seconds: 5));
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> sendMessage(String content) async {
    try {
      final message = await _repository.sendMessage(conversationId, content);
      _ownUserId = message.sender.id;
      state = state.copyWith(messages: [...state.messages, message], hostTyping: true);
      // The server schedules the host auto-reply right away
      _setPollInterval(const Duration(milliseconds: 1500));
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
