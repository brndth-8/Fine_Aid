import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/healthcare_facilities.dart';
import '../../i18n/nearby_strings.dart';
import '../../services/api/nearby_healthcare_service.dart';
import '../../i18n/screen_text_strings.dart';

Future<void> showNearbyHealthcareSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const NearbyHealthcareSheet(),
  );
}

/// The "Find Nearby Healthcare" button: opens the same sheet everywhere
/// (AI result, journal, chat, Animal Scratch notice).
class NearbyHealthcareButton extends StatelessWidget {
  final bool compact;
  const NearbyHealthcareButton({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showNearbyHealthcareSheet(context),
      icon: Icon(Icons.local_hospital_outlined, size: compact ? 16 : 20),
      label: Text(NearbyStrings.of(context).findNearby),
      style: compact
          ? OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            )
          : null,
    );
  }
}

class NearbyHealthcareSheet extends StatefulWidget {
  const NearbyHealthcareSheet({super.key});

  @override
  State<NearbyHealthcareSheet> createState() => _NearbyHealthcareSheetState();
}

class _NearbyHealthcareSheetState extends State<NearbyHealthcareSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _call(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ScreenText.of(
              context,
            ).couldNotOpenDialer.replaceFirst('{number}', phoneNumber),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = NearbyHealthcareService().categories();
    final results = NearbyHealthcareService().search(
      _query,
      category: _selectedCategory,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          // One scrolling list (header, results, note): when the text is large
          // the header can be taller than the sheet, and it then scrolls
          // instead of overflowing.
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        // Shares the row, so a long title wraps instead of
                        // overflowing on a narrow screen or at a large text size.
                        Expanded(
                          child: Text(
                            'Nearby Healthcare',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      // The search stops at 50 characters (typing or pasting).
                      maxLength: 50,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: ScreenText.of(context).searchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 8),
                    // The label sits on its own line above the field (like the
                    // labels on the app's forms), not inside it.
                    Text(
                      ScreenText.of(context).category,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedCategory,
                      // Fill the row, so a long name wraps to an ellipsis instead of
                      // overflowing on a narrow screen or at a large text size.
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            ScreenText.of(context).allCategories,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              if (results.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _query.isEmpty
                          ? ScreenText.of(context).noFacilitiesInCategory
                          : ScreenText.of(
                              context,
                            ).noFacilitiesMatch.replaceFirst('{query}', _query),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) =>
                      _buildFacilityTile(theme, results[index]),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    ScreenText.of(context).directoryNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacilityTile(ThemeData theme, HealthcareFacility facility) {
    final phone = facility.primaryPhoneNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        facility.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (facility.is24Hours)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '24/7',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  facility.category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(facility.address, style: theme.textTheme.bodySmall),
                Text(facility.contact, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              icon: Icon(Icons.call, color: theme.colorScheme.primary),
              tooltip: 'Call $phone',
              onPressed: () => _call(phone),
            ),
        ],
      ),
    );
  }
}
