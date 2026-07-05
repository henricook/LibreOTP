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
    required Future<void> Function() onEdit,
    required double iconWidth,
    required double nameWidth,
    required double accountWidth,
    required double issuerWidth,
    required double otpWidth,
    required double validityWidth,
  }) : super(
          cells: <DataCell>[
            DataCell(
              _buildInteractiveCell(
                width: iconWidth,
                onTap: onTap,
                onEdit: onEdit,
                child: TwoFasIconService.buildServiceIcon(
                  service.name,
                  service.otp.issuer,
                  size: 24.0,
                ),
              ),
            ),
            DataCell(
              _buildInteractiveCell(
                width: nameWidth,
                onTap: onTap,
                onEdit: onEdit,
                child: Text(service.name),
              ),
            ),
            DataCell(
              _buildInteractiveCell(
                width: accountWidth,
                onTap: onTap,
                onEdit: onEdit,
                child: Text(service.otp.account),
              ),
            ),
            DataCell(
              _buildInteractiveCell(
                width: issuerWidth,
                onTap: onTap,
                onEdit: onEdit,
                child: Text(service.otp.issuer),
              ),
            ),
            DataCell(
              _buildInteractiveCell(
                width: otpWidth,
                onTap: onTap,
                onEdit: onEdit,
                child: Text(displayState.otpCode),
              ),
            ),
            DataCell(
              _buildInteractiveCell(
                width: validityWidth,
                onTap: onTap,
                onEdit: onEdit,
                child: Text(displayState.validity),
              ),
            ),
          ],
          onSelectChanged: (_) => onTap(),
        );

  static Widget _buildInteractiveCell({
    required double width,
    required Widget child,
    required VoidCallback onTap,
    required Future<void> Function() onEdit,
  }) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onSecondaryTapDown: (details) async {
            final selectedAction = await showMenu<_ServiceRowAction>(
              context: context,
              position: RelativeRect.fromLTRB(
                details.globalPosition.dx,
                details.globalPosition.dy,
                details.globalPosition.dx,
                details.globalPosition.dy,
              ),
              items: const [
                PopupMenuItem<_ServiceRowAction>(
                  value: _ServiceRowAction.edit,
                  child: Text('Edit entry'),
                ),
              ],
            );

            if (selectedAction == _ServiceRowAction.edit) {
              await onEdit();
            }
          },
          child: SizedBox(
            width: width,
            child: child,
          ),
        );
      },
    );
  }
}

enum _ServiceRowAction {
  edit,
}
