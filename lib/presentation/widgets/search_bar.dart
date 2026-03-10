import 'package:flutter/material.dart';
import '../../config/display_mode.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final Function() onClear;
  final Function(String) onChanged;
  final DisplayMode displayMode;
  final Function(DisplayMode) onDisplayModeChanged;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onClear,
    required this.onChanged,
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: 'Search',
                border: const OutlineInputBorder(),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClear,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<DisplayMode>(
            segments: const [
              ButtonSegment<DisplayMode>(
                value: DisplayMode.grouped,
                icon: Icon(Icons.folder),
                tooltip: 'Group by category',
              ),
              ButtonSegment<DisplayMode>(
                value: DisplayMode.usageBased,
                icon: Icon(Icons.bar_chart),
                tooltip: 'Sort by usage',
              ),
            ],
            selected: {displayMode},
            onSelectionChanged: (Set<DisplayMode> selected) {
              onDisplayModeChanged(selected.first);
            },
          ),
        ],
      ),
    );
  }
}
