import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/features/auth/presentation/screens/login_screen.dart';
import 'package:stayspot/features/auth/presentation/screens/register_screen.dart';
import 'package:stayspot/features/explore/presentation/screens/explore_screen.dart';
import 'package:stayspot/features/listing_detail/presentation/screens/listing_detail_screen.dart';
import 'package:stayspot/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:stayspot/features/booking/presentation/screens/booking_success_screen.dart';
import 'package:stayspot/shared/models/listing_model.dart';
import 'package:stayspot/features/inbox/presentation/screens/chat_screen.dart';
import 'package:stayspot/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:stayspot/features/profile/presentation/screens/host_profile_screen.dart';
import 'package:stayspot/app/splash_screen.dart';
import 'package:stayspot/features/wishlists/presentation/screens/wishlists_screen.dart';
import 'package:stayspot/features/booking/presentation/screens/trips_screen.dart';
import 'package:stayspot/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:stayspot/features/profile/presentation/screens/profile_screen.dart';
import 'package:stayspot/shared/widgets/bottom_nav_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/listing/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ListingDetailScreen(
        listingId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/booking',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return BookingConfirmationScreen(
          listing: data['listing'] as ListingModel,
          checkIn: data['checkIn'] as DateTime,
          checkOut: data['checkOut'] as DateTime,
          guests: data['guests'] as int? ?? 1,
        );
      },
    ),
    GoRoute(
      path: '/booking-success',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BookingSuccessScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ChatScreen(
        conversationId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/edit-profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/host/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => HostProfileScreen(
        hostId: state.pathParameters['id']!,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BottomNavScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/wishlists',
              builder: (context, state) => const WishlistsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trips',
              builder: (context, state) => const TripsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inbox',
              builder: (context, state) => const InboxScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
