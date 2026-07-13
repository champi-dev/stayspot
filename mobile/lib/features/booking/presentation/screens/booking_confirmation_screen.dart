import 'package:flutter/material.dart';
import 'package:stayspot/shared/widgets/app_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/core/constants.dart';
import 'package:stayspot/features/booking/presentation/providers/booking_provider.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  final ListingModel listing;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;

  const BookingConfirmationScreen({
    super.key,
    required this.listing,
    required this.checkIn,
    required this.checkOut,
    this.guests = 1,
  });

  @override
  ConsumerState<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends ConsumerState<BookingConfirmationScreen> {
  bool _isProcessing = false;
  late DateTime _checkIn;
  late DateTime _checkOut;
  late int _guests;

  @override
  void initState() {
    super.initState();
    _checkIn = widget.checkIn;
    _checkOut = widget.checkOut;
    _guests = widget.guests;
  }

  int get _nights => _checkOut.difference(_checkIn).inDays;
  double get _nightlyTotal => widget.listing.pricePerNight * _nights;
  double get _total => _nightlyTotal + widget.listing.cleaningFee + widget.listing.serviceFee;

  Future<void> _editDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _checkIn = range.start;
        _checkOut = range.end;
      });
    }
  }

  void _editGuests() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Guests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _guests > 1 ? () => setModalState(() => setState(() => _guests--)) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('$_guests', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: _guests < widget.listing.maxGuests ? () => setModalState(() => setState(() => _guests++)) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndPay() async {
    setState(() => _isProcessing = true);

    final result = await ref.read(bookingProvider.notifier).createAndConfirmBooking(
          listingId: widget.listing.id,
          checkIn: _checkIn.toIso8601String().split('T')[0],
          checkOut: _checkOut.toIso8601String().split('T')[0],
          guests: _guests,
        );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (result != null) {
        context.go('/booking-success');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm and Pay')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing mini-card
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: listing.images.isNotEmpty
                      ? AppNetworkImage('${ApiConstants.imageBaseUrl}${listing.images[0].url}',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80, height: 80, color: AppColors.surface,
                          child: const Icon(Icons.home, color: AppColors.textTertiary),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: AppColors.textPrimary),
                          const SizedBox(width: 2),
                          Text(
                            listing.averageRating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            ' (${listing.reviewCount})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Trip details
            const Text('Your trip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _editableDetailRow('Dates', '${_formatDate(_checkIn)} - ${_formatDate(_checkOut)}', _editDates),
            _editableDetailRow('Guests', '$_guests guest${_guests > 1 ? 's' : ''}', _editGuests),
            const Divider(height: 32),

            // Price breakdown
            const Text('Price details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _priceRow('\$${listing.pricePerNight.toInt()} x $_nights nights', '\$${_nightlyTotal.toInt()}'),
            _priceRow('Cleaning fee', '\$${listing.cleaningFee.toInt()}'),
            _priceRow('Service fee', '\$${listing.serviceFee.toInt()}'),
            const Divider(height: 24),
            _priceRow('Total', '\$${_total.toInt()}', bold: true),
            const Divider(height: 32),

            // Mock payment card
            const Text('Pay with', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D3436), Color(0xFF636E72)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('VISA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('•••• 4242', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: AppShadows.stickyBar,
        ),
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _confirmAndPay,
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirm and Pay'),
        ),
      ),
    );
  }

  Widget _editableDetailRow(String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Text(
              'Edit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _priceRow(String label, String amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            decoration: bold ? null : TextDecoration.underline,
          )),
          Text(amount, style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          )),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
