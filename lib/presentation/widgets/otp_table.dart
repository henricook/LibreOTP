import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../data/models/otp_service.dart';
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
      dataRowMinHeight: kRowMinHeight,
      dataRowMaxHeight: kRowMaxHeight,
      headingRowHeight: kHeaderHeight,
      dividerThickness: kDividerThickness,
    );
  }

  List<DataColumn> _buildColumns() {
    return const <DataColumn>[
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
    
    final columnWidths = _calculateColumnWidths(constraints.maxWidth);
    final List<DataRow> rows = [];
    
    // Sort groups for consistent display - Ungrouped always last
    final sortedEntries = _getSortedEntries();
    
    for (final entry in sortedEntries) {
      // Get group name from mapping or use a default
      String groupName = groupNames[entry.key] ?? 'Unknown Group';
      
      // Add group header row
      rows.add(GroupHeader(groupName: groupName));
      
      // Add service rows
      final services = entry.value;
      for (int i = 0; i < services.length; i++) {
        rows.add(
          ServiceRow(
            service: services[i],
            onTap: () => onRowTap(entry.key, i),
            nameWidth: columnWidths['name']!,
            accountWidth: columnWidths['account']!,
            issuerWidth: columnWidths['issuer']!,
            otpWidth: columnWidths['otp']!,
            validityWidth: columnWidths['validity']!,
          ),
        );
      }
    }
    
    return rows;
  }
  
  List<MapEntry<String, List<OtpService>>> _getSortedEntries() {
    // Extract entries and sort them
    final entries = groupedServices.entries.toList();
    
    // Custom sort: Ungrouped always last, others alphabetically by group name
    entries.sort((a, b) {
      if (a.key == kUngroupedId) return 1; // Ungrouped always at the end
      if (b.key == kUngroupedId) return -1; // Ungrouped always at the end
      
      // Default to alphabetical by group name
      final aName = groupNames[a.key] ?? '';
      final bName = groupNames[b.key] ?? '';
      return aName.compareTo(bName);
    });
    
    return entries;
  }
  
  Map<String, double> _calculateColumnWidths(double totalWidth) {
    return {
      'name': totalWidth * 0.25,
      'account': totalWidth * 0.25,
      'issuer': totalWidth * 0.1,
      'otp': totalWidth * 0.1,
      'validity': totalWidth * 0.05,
    };
  }
}