import 'package:flutter/material.dart';

class GroupHeader extends DataRow {
  GroupHeader({
    super.key,
    required String groupName,
  }) : super(
          color: WidgetStateProperty.all(Colors.grey.shade200),
          cells: [
            DataCell(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  groupName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              placeholder: true,
            ),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
          ],
        );
}
