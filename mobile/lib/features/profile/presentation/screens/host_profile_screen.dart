import 'package:flutter/material.dart';
import 'package:stayspot/shared/widgets/app_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/core/api_client.dart';
import 'package:stayspot/core/constants.dart';

class HostProfileScreen extends StatefulWidget {
  final String hostId;

  const HostProfileScreen({super.key, required this.hostId});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen> {
  Map<String, dynamic>? _host;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHost();
  }

  Future<void> _loadHost() async {
    try {
      final response = await ApiClient().dio.get('/users/${widget.hostId}/public');
      setState(() {
        _host = response.data['user'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_host == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Host not found')),
      );
    }

    final host = _host!;
    final listings = host['listings'] as List? ?? [];
    final createdAt = DateTime.tryParse(host['createdAt'] as String? ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Host profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.surface,
              child: Text(
                (host['firstName'] as String? ?? '?')[0],
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${host['firstName']} ${host['lastName']}',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            if (host['isSuperhost'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.star.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: AppColors.star),
                    SizedBox(width: 4),
                    Text('Superhost', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFB8860B))),
                  ],
                ),
              ),
            ],
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Member since ${createdAt.year}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat('${host['reviewCount'] ?? 0}', 'Reviews'),
                const SizedBox(width: 32),
                _stat((host['averageRating'] as num?)?.toStringAsFixed(1) ?? '–', 'Rating'),
                const SizedBox(width: 32),
                _stat('${host['listingCount'] ?? 0}', 'Listings'),
              ],
            ),
            const SizedBox(height: 16),

            // Bio
            if (host['bio'] != null && (host['bio'] as String).isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  host['bio'] as String,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Listings
            if (listings.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${host['firstName']}'s listings",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              ...listings.map((l) {
                final images = l['images'] as List? ?? [];
                final imageUrl = images.isNotEmpty ? images[0]['url'] as String? : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => context.push('/listing/${l['id']}'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                            child: imageUrl != null
                                ? AppNetworkImage('${ApiConstants.imageBaseUrl}$imageUrl',
                                    width: 100, height: 100, fit: BoxFit.cover,
                                  )
                                : Container(width: 100, height: 100, color: AppColors.surface),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l['title'] as String? ?? '',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${(l['pricePerNight'] as num?)?.toInt() ?? 0} / night',
                                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
