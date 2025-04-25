import 'package:flutter/material.dart';
import '../../data/models/otp_service.dart';

class ServiceRow extends DataRow {
  ServiceRow({
    super.key,
    required OtpService service,
    required Function() onTap,
    required double nameWidth,
    required double accountWidth,
    required double issuerWidth,
    required double otpWidth,
    required double validityWidth,
  }) : super(
          cells: <DataCell>[
            DataCell(
              SizedBox(
                width: nameWidth,
                child: Text(service.name),
              ),
            ),
            DataCell(
              SizedBox(
                width: accountWidth,
                child: Text(service.otp.account),
              ),
            ),
            DataCell(
              SizedBox(
                width: issuerWidth,
                child: Text(service.otp.issuer),
              ),
            ),
            DataCell(
              SizedBox(
                width: otpWidth,
                child: Text(service.otpCode ?? ''),
              ),
            ),
            DataCell(
              SizedBox(
                width: validityWidth,
                child: Text(service.validity ?? ''),
              ),
            ),
          ],
          onSelectChanged: (_) => onTap(),
        );
}