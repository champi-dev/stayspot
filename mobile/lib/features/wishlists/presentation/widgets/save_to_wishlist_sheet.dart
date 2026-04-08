import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/wishlists/presentation/providers/wishlist_provider.dart';

class SaveToWishlistSheet extends ConsumerStatefulWidget {
  final String listingId;

  const SaveToWishlistSheet({super.key, required this.listingId});

  @override
  ConsumerState<SaveToWishlistSheet> createState() => _SaveToWishlistSheetState();
}

class _SaveToWishlistSheetState extends ConsumerState<SaveToWishlistSheet> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    ref.read(wishlistProvider.notifier).loadWishlists();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAndAdd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final wishlist = await ref.read(wishlistProvider.notifier).createWishlist(name);
      await ref.read(wishlistProvider.notifier).addListing(wishlist.id, widget.listingId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wishlistProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Save to wishlist',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Existing wishlists
          if (state.wishlists.isNotEmpty) ...[
            ...state.wishlists.map((wishlist) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.favorite, color: AppColors.textTertiary),
              ),
              title: Text(wishlist.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${wishlist.listingCount} saved'),
              onTap: () async {
                await ref.read(wishlistProvider.notifier).addListing(wishlist.id, widget.listingId);
                if (context.mounted) Navigator.of(context).pop(true);
              },
            )),
            const Divider(),
          ],

          // Create new
          const SizedBox(height: 8),
          const Text('Create new wishlist', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Wishlist name'),
                  onSubmitted: (_) => _createAndAdd(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isCreating ? null : _createAndAdd,
                style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
                child: _isCreating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
