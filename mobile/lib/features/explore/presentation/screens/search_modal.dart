import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/app/theme.dart';
import 'package:stayspot/features/explore/presentation/providers/explore_provider.dart';
import 'package:stayspot/shared/models/listing_model.dart';

class SearchModal extends ConsumerStatefulWidget {
  const SearchModal({super.key});

  @override
  ConsumerState<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends ConsumerState<SearchModal> {
  final _searchController = TextEditingController();
  AutocompleteSuggestion? _selectedSuggestion;
  DateTimeRange? _dateRange;
  int _guests = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectSuggestion(AutocompleteSuggestion suggestion) {
    setState(() {
      _selectedSuggestion = suggestion;
      _searchController.text = suggestion.description;
    });
    ref.read(exploreProvider.notifier).searchAutocomplete('');
  }

  void _search() {
    if (_selectedSuggestion == null) return;
    ref.read(exploreProvider.notifier).selectLocation(_selectedSuggestion!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final exploreState = ref.watch(exploreProvider);
    final hasSelection = _selectedSuggestion != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WHERE
                  const Text('Where', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search destinations',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(exploreProvider.notifier).searchAutocomplete('');
                                setState(() => _selectedSuggestion = null);
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      ref.read(exploreProvider.notifier).searchAutocomplete(value);
                      setState(() => _selectedSuggestion = null);
                    },
                    onSubmitted: (_) {
                      if (exploreState.suggestions.isNotEmpty) {
                        _selectSuggestion(exploreState.suggestions.first);
                      }
                    },
                  ),

                  // Autocomplete suggestions
                  if (!hasSelection && exploreState.suggestions.isNotEmpty)
                    ...exploreState.suggestions.map((suggestion) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place_outlined, color: AppColors.textSecondary),
                          title: Text(suggestion.mainText, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(suggestion.secondaryText, style: const TextStyle(color: AppColors.textSecondary)),
                          onTap: () => _selectSuggestion(suggestion),
                        )),

                  // Date & guest sections show after location is selected
                  if (hasSelection) ...[
                    const SizedBox(height: 24),

                    // WHEN
                    const Text('When', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
                            ),
                            child: child!,
                          ),
                        );
                        if (range != null) setState(() => _dateRange = range);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: _dateRange != null ? Border.all(color: AppColors.primary, width: 1.5) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: _dateRange != null ? AppColors.primary : AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Text(
                              _dateRange != null
                                  ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                                  : 'Add dates (optional)',
                              style: TextStyle(
                                fontSize: 16,
                                color: _dateRange != null ? AppColors.textPrimary : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // WHO
                    const Text('Guests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            '$_guests guest${_guests > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                            icon: Icon(Icons.remove_circle_outline,
                                color: _guests > 1 ? AppColors.textPrimary : AppColors.divider),
                          ),
                          IconButton(
                            onPressed: _guests < 12 ? () => setState(() => _guests++) : null,
                            icon: Icon(Icons.add_circle_outline,
                                color: _guests < 12 ? AppColors.textPrimary : AppColors.divider),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom search button
          if (hasSelection)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: AppShadows.stickyBar,
              ),
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
