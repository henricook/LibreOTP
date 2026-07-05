import 'package:flutter/material.dart';

class GroupHeader extends DataRow {
  GroupHeader({
    super.key,
    required String groupName,
    required Color backgroundColor,
    required Color textColor,
  }) : super(
          color: WidgetStateProperty.all(backgroundColor),
          cells: [
            const DataCell(Text('')), // Icon column
            DataCell(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  groupName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
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
