import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/inbox/presentation/providers/inbox_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ref.read(chatProvider(widget.conversationId).notifier).stopPolling();
    // Refresh inbox so badge updates
    ref.read(inboxProvider.notifier).loadConversations();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(chatProvider(widget.conversationId).notifier).sendMessage(content);
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider(widget.conversationId));
    final auth = ref.watch(authProvider);
    final currentUserId = auth.user?.id;

    // Auto-scroll when a new message arrives (e.g. the host's reply)
    ref.listen(chatProvider(widget.conversationId), (previous, next) {
      final grew = (previous?.messages.length ?? 0) < next.messages.length;
      final startedTyping = !(previous?.hostTyping ?? false) && next.hostTyping;
      if (grew || startedTyping) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          Expanded(
            child: chat.isLoading && chat.messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: chat.messages.length + (chat.hostTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(children: [_TypingBubble()]),
                        );
                      }
                      final message = chat.messages[index];
                      final isOwn = message.sender.id == currentUserId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isOwn ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isOwn ? 16 : 4),
                                  bottomRight: Radius.circular(isOwn ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isOwn ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOwn ? Colors.white70 : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(
              12, 8, 12, 8 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// "Host is typing" chat bubble with three pulsing dots.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_controller.value * 3 - i).clamp(0.0, 1.0);
              final bounce = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              return Padding(
                padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                child: Transform.translate(
                  offset: Offset(0, -3 * bounce),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
