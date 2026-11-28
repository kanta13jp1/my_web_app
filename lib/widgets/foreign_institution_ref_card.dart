import 'package:flutter/material.dart';
import 'package:my_web_app/services/foreign_institution_ref_service.dart';

/// Filterable foreign institutional comparison reference card (#2808).
class ForeignInstitutionRefCard extends StatefulWidget {
  const ForeignInstitutionRefCard({
    super.key,
    required this.entries,
    this.onOpenOfficialUrl,
  });

  final List<ForeignInstitutionEntry> entries;
  final void Function(String officialUrl)? onOpenOfficialUrl;

  @override
  State<ForeignInstitutionRefCard> createState() =>
      _ForeignInstitutionRefCardState();
}

class _ForeignInstitutionRefCardState extends State<ForeignInstitutionRefCard> {
  String? _selectedCountry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countries = widget.entries
        .map((ForeignInstitutionEntry e) => e.countryCode)
        .toSet()
        .toList()
      ..sort();

    final filtered = _selectedCountry == null
        ? widget.entries
        : widget.entries
            .where(
              (ForeignInstitutionEntry e) => e.countryCode == _selectedCountry,
            )
            .toList();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '諸外国の制度比較リファレンス',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('すべて'),
                  selected: _selectedCountry == null,
                  onSelected: (_) => setState(() => _selectedCountry = null),
                ),
                for (final code in countries)
                  ChoiceChip(
                    label: Text(code),
                    selected: _selectedCountry == code,
                    onSelected: (_) => setState(() => _selectedCountry = code),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Text(
                '該当する制度事例はありません。',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final entry in filtered)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${entry.countryName} (${entry.category.label})',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.title,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.summary,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Text(
                                    '引用: ${entry.citedSpeechIds.length}件',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(64, 48),
                                    ),
                                    onPressed: widget.onOpenOfficialUrl == null
                                        ? null
                                        : () => widget.onOpenOfficialUrl!(
                                              entry.officialUrl,
                                            ),
                                    child: const Text('参照'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
