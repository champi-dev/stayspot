import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/core/constants.dart';
import 'package:stayspot/features/auth/presentation/providers/auth_provider.dart';
import 'package:stayspot/features/booking/data/booking_repository.dart';
import 'package:stayspot/features/booking/presentation/providers/booking_provider.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated) {
        ref.read(bookingProvider.notifier).loadBookings();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bookings = ref.watch(bookingProvider);

    if (auth.status != AuthStatus.authenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.luggage_outlined, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('Your trips', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                const Text(
                  'Log in to see your bookings',
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
      appBar: AppBar(
        title: const Text('Trips'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: bookings.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(bookings.upcoming, isEmpty: 'No upcoming trips'),
                _buildBookingList(bookings.past, isEmpty: 'No past trips'),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<BookingModel> bookings, {required String isEmpty}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.luggage_outlined, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(isEmpty, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Start exploring to book your next trip!', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/explore'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
              child: const Text('Start exploring'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(bookingProvider.notifier).loadBookings(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildTripCard(booking);
        },
      ),
    );
  }

  Widget _buildTripCard(BookingModel booking) {
    return GestureDetector(
      onTap: () {
        if (booking.listing != null) {
          context.push('/listing/${booking.listing!.id}');
        }
      },
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        color: AppColors.background,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: booking.listing?.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: '${ApiConstants.imageBaseUrl}${booking.listing!.imageUrl}',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 120, height: 120, color: AppColors.surface,
                      child: const Icon(Icons.home, size: 32, color: AppColors.textTertiary),
                    ),
                  )
                : Container(
                    width: 120, height: 120, color: AppColors.surface,
                    child: const Icon(Icons.home, size: 32, color: AppColors.textTertiary),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.listing?.title ?? 'Booking',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.listing?.locationName ?? '',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(booking.checkIn)} - ${_formatDate(booking.checkOut)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _statusChip(booking.status),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _statusChip(String status) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'CONFIRMED':
        bg = AppColors.secondary.withValues(alpha: 0.15);
        fg = AppColors.secondary;
        break;
      case 'CANCELLED':
        bg = AppColors.error.withValues(alpha: 0.15);
        fg = AppColors.error;
        break;
      case 'COMPLETED':
        bg = AppColors.textTertiary.withValues(alpha: 0.15);
        fg = AppColors.textSecondary;
        break;
      default:
        bg = AppColors.star.withValues(alpha: 0.15);
        fg = const Color(0xFFB8860B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
