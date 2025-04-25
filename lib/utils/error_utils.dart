import 'package:flutter/material.dart';

enum ErrorSeverity {
  info,
  warning,
  error,
  critical
}

class ErrorUtils {
  static void logError(String message, {Object? error, StackTrace? stackTrace, ErrorSeverity severity = ErrorSeverity.error}) {
    // Future implementation could integrate with a logging service
    debugPrint('[$severity] $message');
    if (error != null) {
      debugPrint('Error details: $error');
    }
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  static void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}