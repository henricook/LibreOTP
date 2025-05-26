import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_config.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About LibreOTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppConfig.appTitle),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () =>
                Clipboard.setData(ClipboardData(text: AppConfig.githubUrl)),
            child: Text(
              AppConfig.githubUrl,
              style: const TextStyle(
                  color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
