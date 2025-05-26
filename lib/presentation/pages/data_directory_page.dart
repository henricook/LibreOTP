import 'package:flutter/material.dart';

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
      content: Text('Path to the Documents folder:\n\n$dataDirectory'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
