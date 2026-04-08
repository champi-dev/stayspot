import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/inbox/presentation/providers/inbox_provider.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated) {
        ref.read(inboxProvider.notifier).loadConversations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final inbox = ref.watch(inboxProvider);

    if (auth.status != AuthStatus.authenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('Inbox', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                const Text(
                  'Log in to see your messages',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: inbox.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : inbox.conversations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textTertiary),
                      SizedBox(height: 16),
                      Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text(
                        'Contact a host to start a conversation',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(inboxProvider.notifier).loadConversations(),
                  child: ListView.separated(
                    itemCount: inbox.conversations.length,
                    separatorBuilder: (_, _) => const Divider(indent: 76),
                    itemBuilder: (context, index) {
                      final conversation = inbox.conversations[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.surface,
                          child: Text(
                            conversation.otherUser?.firstName[0] ?? '?',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        title: Text(
                          conversation.otherUser?.fullName ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          conversation.lastMessage?.content ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: conversation.lastMessage != null
                            ? Text(
                                _formatTime(conversation.lastMessage!.createdAt),
                                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              )
                            : null,
                        onTap: () => context.push('/chat/${conversation.id}'),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }
}
