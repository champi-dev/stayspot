import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/inbox/presentation/providers/inbox_provider.dart';

class BottomNavScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends ConsumerState<BottomNavScaffold> {
  Timer? _inboxPollTimer;

  @override
  void initState() {
    super.initState();
    // Start polling for new messages every 10 seconds
    _inboxPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated) {
        ref.read(inboxProvider.notifier).loadConversations();
      }
    });
    // Also load immediately
    Future.microtask(() {
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated) {
        ref.read(inboxProvider.notifier).loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _inboxPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final hasUnread = inbox.conversations.any(
      (c) => c.lastMessage != null && !c.lastMessage!.isRead && !c.lastMessage!.isOwn,
    );

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: const Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: BottomNavigationBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              ),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.search_outlined),
                  activeIcon: Icon(Icons.search),
                  label: 'Explore',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_outline),
                  activeIcon: Icon(Icons.favorite),
                  label: 'Wishlists',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.luggage_outlined),
                  activeIcon: Icon(Icons.luggage),
                  label: 'Trips',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: hasUnread,
                    backgroundColor: AppColors.primary,
                    smallSize: 8,
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: hasUnread,
                    backgroundColor: AppColors.primary,
                    smallSize: 8,
                    child: const Icon(Icons.chat_bubble),
                  ),
                  label: 'Inbox',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
