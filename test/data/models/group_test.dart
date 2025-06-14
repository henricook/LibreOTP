import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/group.dart';

void main() {
  group('Group', () {
    test('should create a Group with all fields', () {
      const group = Group(
        id: 'test-id',
        name: 'Test Group',
      );

      expect(group.id, equals('test-id'));
      expect(group.name, equals('Test Group'));
    });

    test('should create Group from JSON', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Group',
      };

      final group = Group.fromJson(json);

      expect(group.id, equals('test-id'));
      expect(group.name, equals('Test Group'));
    });

    test('should convert Group to JSON', () {
      const group = Group(
        id: 'test-id',
        name: 'Test Group',
      );

      final json = group.toJson();

      expect(json, equals({
        'id': 'test-id',
        'name': 'Test Group',
      }));
    });

    test('should handle equality correctly', () {
      const group1 = Group(
        id: 'test-id',
        name: 'Test Group',
      );

      const group2 = Group(
        id: 'test-id',
        name: 'Test Group',
      );

      const group3 = Group(
        id: 'different-id',
        name: 'Test Group',
      );

      expect(group1, equals(group2));
      expect(group1, isNot(equals(group3)));
    });

    test('should have consistent hashCode', () {
      const group1 = Group(
        id: 'test-id',
        name: 'Test Group',
      );

      const group2 = Group(
        id: 'test-id',
        name: 'Test Group',
      );

      expect(group1.hashCode, equals(group2.hashCode));
    });

    test('should handle invalid JSON gracefully', () {
      // The Group.fromJson actually handles empty JSON by providing defaults
      final emptyGroup = Group.fromJson({});
      expect(emptyGroup.id, equals(''));
      expect(emptyGroup.name, equals(''));
    });
  });
}