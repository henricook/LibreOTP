import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/otp_service.dart';
import '../state/otp_state.dart';
import 'group_header.dart';
import 'service_row.dart';

class OtpTable extends StatelessWidget {
  final Map<String, List<OtpService>> groupedServices;
  final Map<String, String> groupNames;
  final void Function(OtpService service) onRowTap;
  final Future<void> Function(OtpService service) onEditService;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending) onSort;

  const OtpTable({
    super.key,
    required this.groupedServices,
    required this.groupNames,
    required this.onRowTap,
    required this.onEditService,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      showCheckboxColumn: false,
      sortAscending: sortAscending,
      sortColumnIndex: sortColumnIndex,
      columns: _buildColumns(),
      rows: _buildRows(context),
      dataRowMinHeight: 28.0,
      dataRowMaxHeight: 28.0,
      headingRowHeight: 40.0,
      dividerThickness: 0.5,
    );
  }

  List<DataColumn> _buildColumns() {
    return <DataColumn>[
      DataColumn(
        label: SizedBox(
          width: 40,
          child: Text(
            '',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      DataColumn(
        label: Expanded(
          child: Text(
            'Name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: Expanded(
          child: Text(
            'Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: Text(
          'Issuer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onSort: onSort,
      ),
      DataColumn(
        label: Text(
          'OTP Value',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DataColumn(
        label: Text(
          'Validity',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ];
  }

  List<DataRow> _buildRows(BuildContext context) {
    final constraints = BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final iconWidth = 40.0;
    final nameWidth = constraints.maxWidth * 0.22;
    final accountWidth = constraints.maxWidth * 0.22;
    final issuerWidth = constraints.maxWidth * 0.1;
    final otpWidth = constraints.maxWidth * 0.1;
    final validityWidth = constraints.maxWidth * 0.05;

    final otpState = Provider.of<OtpState>(context);
    List<DataRow> rows = [];

    for (final entry in groupedServices.entries) {
      String groupName = groupNames[entry.key] ?? 'Unknown Group';
      final sortedServices =
          sortServicesForTable(entry.value, sortColumnIndex, sortAscending);

      // Add group header row
      rows.add(
        GroupHeader(
          key: ValueKey('header:${entry.key}'),
          groupName: groupName,
          backgroundColor: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurface,
        ),
      );

      // Add service rows
      for (final service in sortedServices) {
        final displayState = otpState.getOtpDisplayState(service.id);
        rows.add(
          ServiceRow(
            key: ValueKey(service.id),
            service: service,
            displayState: displayState,
            onTap: () => onRowTap(service),
            onEdit: () => onEditService(service),
            iconWidth: iconWidth,
            nameWidth: nameWidth,
            accountWidth: accountWidth,
            issuerWidth: issuerWidth,
            otpWidth: otpWidth,
            validityWidth: validityWidth,
          ),
        );
      }
    }

    return rows;
  }
}

List<OtpService> sortServicesForTable(
  List<OtpService> services,
  int? sortColumnIndex,
  bool sortAscending,
) {
  if (sortColumnIndex == null || !const {1, 2, 3}.contains(sortColumnIndex)) {
    return List<OtpService>.from(services);
  }

  final sortedServices = List<OtpService>.from(services)
    ..sort((a, b) {
      final left = switch (sortColumnIndex) {
        1 => a.name,
        2 => a.otp.account,
        3 => a.otp.issuer,
        _ => '',
      };
      final right = switch (sortColumnIndex) {
        1 => b.name,
        2 => b.otp.account,
        3 => b.otp.issuer,
        _ => '',
      };

      final comparison = left.toLowerCase().compareTo(right.toLowerCase());
      if (comparison != 0) {
        return sortAscending ? comparison : -comparison;
      }

      final fallback = a.order.position.compareTo(b.order.position);
      return sortAscending ? fallback : -fallback;
    });

  return sortedServices;
}
