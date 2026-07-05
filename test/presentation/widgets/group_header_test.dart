import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/presentation/widgets/group_header.dart';

void main() {
  test('uses supplied colors for themed group headers', () {
    const backgroundColor = Colors.black;
    const textColor = Colors.white;

    final header = GroupHeader(
      groupName: 'Ungrouped',
      backgroundColor: backgroundColor,
      textColor: textColor,
    );

    expect(header.color?.resolve({}), equals(backgroundColor));

    final groupNameCell = header.cells[1];
    final paddedText = groupNameCell.child as Padding;
    final text = paddedText.child as Text;

    expect(text.data, equals('Ungrouped'));
    expect(text.style?.color, equals(textColor));
  });
}
