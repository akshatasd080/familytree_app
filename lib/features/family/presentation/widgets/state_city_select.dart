import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/india_locations.dart';

/// Cascading State → City dropdowns.
/// Emits a single location string via [onChanged]: `"City, State"`.
class StateCitySelect extends StatefulWidget {
  const StateCitySelect({
    super.key,
    this.value = '',
    required this.onChanged,
    this.required = false,
    this.showHint = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool required;
  final bool showHint;

  @override
  State<StateCitySelect> createState() => _StateCitySelectState();
}

class _StateCitySelectState extends State<StateCitySelect> {
  late String _state;
  late String _city;

  @override
  void initState() {
    super.initState();
    _syncFromValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant StateCitySelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncFromValue(widget.value);
    }
  }

  void _syncFromValue(String value) {
    final parsed = parseLocation(value);
    _state = parsed.state;
    _city = parsed.city;
  }

  void _setState(String? next) {
    setState(() {
      _state = next ?? '';
      _city = '';
    });
    widget.onChanged(formatLocation('', _state));
  }

  void _setCity(String? next) {
    setState(() => _city = next ?? '');
    widget.onChanged(formatLocation(_city, _state));
  }

  @override
  Widget build(BuildContext context) {
    final cities = citiesForState(_state);
    final states = indiaStates;
    final stateValue = states.contains(_state) ? _state : null;
    final cityValue =
        _city.isNotEmpty && cities.contains(_city) ? _city : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: stateValue,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: widget.required ? 'State *' : 'State',
                ),
                items: [
                  for (final s in states)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _setState,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: cityValue,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      widget.required ? 'District / City *' : 'District / City',
                ),
                items: [
                  for (final c in cities)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: _state.isEmpty ? null : _setCity,
              ),
            ),
          ],
        ),
        if (widget.showHint) ...[
          const SizedBox(height: 4),
          Text(
            'Used for family map. Format: City, State',
            style: AppTheme.body(size: 11, color: AppTheme.muted),
          ),
        ],
      ],
    );
  }
}
