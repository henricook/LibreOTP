import 'package:flutter/material.dart';
import '../../data/models/otp_service.dart';
import '../../services/twofas_icon_service.dart';
import '../state/otp_display_state.dart';

class ServiceRow extends DataRow {
  ServiceRow({
    super.key,
    required OtpService service,
    required OtpDisplayState displayState,
    required Function() onTap,
    required double iconWidth,
    required double nameWidth,
    required double accountWidth,
    required double issuerWidth,
    required double otpWidth,
    required double validityWidth,
  }) : super(
          cells: <DataCell>[
            DataCell(
              SizedBox(
                width: iconWidth,
                child: TwoFasIconService.buildServiceIcon(
                  service.name,
                  service.otp.issuer,
                  size: 24.0,
                ),
              ),
            ),
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
                child: Text(displayState.otpCode),
              ),
            ),
            DataCell(
              SizedBox(
                width: validityWidth,
                child: Text(displayState.validity),
              ),
            ),
          ],
          onSelectChanged: (_) => onTap(),
        );
}
