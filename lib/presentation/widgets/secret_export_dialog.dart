import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/otp_service.dart';
import '../../utils/clipboard_utils.dart';

class SecretExportDialog extends StatelessWidget {
  final OtpService service;

  const SecretExportDialog({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (service.otp.account.isNotEmpty) service.otp.account,
      if (service.otp.issuer.isNotEmpty) service.otp.issuer,
    ].join(' - ');

    return AlertDialog(
      title: Text(service.name.isNotEmpty ? service.name : 'Secret'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) ...[
              Text(subtitle),
              const SizedBox(height: 16),
            ],
            _SecretField(
              label: 'Secret key',
              value: service.normalizedSecret,
            ),
            const SizedBox(height: 12),
            _SecretField(
              label: 'otpauth URI',
              value: service.toOtpAuthUri(),
            ),
            const SizedBox(height: 12),
            Text(
              '${service.otp.algorithm.toUpperCase()}, '
              '${service.otp.digits} digits, ${service.otp.period}s period. '
              'Anyone with this secret can generate your codes.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SecretField extends StatefulWidget {
  final String label;
  final String value;

  const _SecretField({required this.label, required this.value});

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  Timer? _copiedTimer;

  bool get _copied => _copiedTimer?.isActive ?? false;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await ClipboardUtils.copyToClipboard(widget.value);
    if (!mounted) {
      return;
    }
    _copiedTimer?.cancel();
    setState(() {
      _copiedTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _copied ? 'Copied' : 'Copy ${widget.label}',
          icon: Icon(_copied ? Icons.check : Icons.copy),
          onPressed: _copy,
        ),
      ),
      child: SelectableText(
        widget.value,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}
