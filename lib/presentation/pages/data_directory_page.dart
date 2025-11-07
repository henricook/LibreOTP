import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DataDirectoryPage extends StatelessWidget {
  final String dataDirectory;

  const DataDirectoryPage({
    super.key,
    required this.dataDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Data Directory'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Path to the Documents folder:'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: SelectableText(
              dataDirectory,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: You can select and copy the path above',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: dataDirectory));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Path copied to clipboard!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy Path'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
