import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/otp_service.dart';
import '../state/otp_state.dart';
import 'group_header.dart';
import 'service_row.dart';

class OtpTable extends StatelessWidget {
  final Map<String, List<OtpService>> groupedServices;
  final Map<String, String> groupNames;
  final Function(String, int) onRowTap;
  final bool sortAscending;

  const OtpTable({
    super.key,
    required this.groupedServices,
    required this.groupNames,
    required this.onRowTap,
    required this.sortAscending,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      showCheckboxColumn: false,
      sortAscending: sortAscending,
      sortColumnIndex: 1,
      columns: _buildColumns(),
      rows: _buildRows(context),
      dataRowMinHeight: 28.0,
      dataRowMaxHeight: 28.0,
      headingRowHeight: 40.0,
      dividerThickness: 0.5,
    );
  }

  List<DataColumn> _buildColumns() {
    return const <DataColumn>[
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
      ),
      DataColumn(
        label: Expanded(
          child: Text(
            'Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      DataColumn(
        label: Text(
          'Issuer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

      // Add group header row
      rows.add(GroupHeader(groupName: groupName));

      // Add service rows
      for (int i = 0; i < entry.value.length; i++) {
        OtpService service = entry.value[i];
        final serviceKey = '${entry.key}-$i';
        final displayState = otpState.getOtpDisplayState(serviceKey);
        rows.add(
          ServiceRow(
            service: service,
            displayState: displayState,
            onTap: () => onRowTap(entry.key, i),
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
