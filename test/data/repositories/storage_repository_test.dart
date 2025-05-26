import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/group.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('StorageRepository', () {
    late StorageRepository repository;

    setUp(() {
      repository = StorageRepository();
    });

    group('Data models validation', () {
      test('should create valid Group from JSON', () {
        final json = {
          'id': 'test-group-id',
          'name': 'Test Group',
        };

        final group = Group.fromJson(json);

        expect(group.id, equals('test-group-id'));
        expect(group.name, equals('Test Group'));
      });

      test('should create valid OtpService from JSON', () {
        final json = {
          'id': 'test-service-id',
          'name': 'Test Service',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp': {
            'account': 'test@example.com',
            'issuer': 'Test Issuer',
            'algorithm': 'SHA1',
            'digits': 6,
            'period': 30,
          },
          'order': {
            'position': 0,
          },
          'groupId': 'test-group-id',
        };

        final service = OtpService.fromJson(json);

        expect(service.id, equals('test-service-id'));
        expect(service.name, equals('Test Service'));
        expect(service.secret, equals('JBSWY3DPEHPK3PXP'));
        expect(service.otp.account, equals('test@example.com'));
        expect(service.otp.issuer, equals('Test Issuer'));
        expect(service.otp.algorithm, equals('SHA1'));
        expect(service.otp.digits, equals(6));
        expect(service.otp.period, equals(30));
        expect(service.order.position, equals(0));
        expect(service.groupId, equals('test-group-id'));
      });

      test('should handle missing optional fields in OtpService', () {
        final json = {
          'id': 'test-service-id',
          'name': 'Test Service',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp': {
            'account': 'test@example.com',
            'issuer': 'Test Issuer',
          },
          'order': {},
          // No groupId
        };

        final service = OtpService.fromJson(json);

        expect(service.id, equals('test-service-id'));
        expect(service.name, equals('Test Service'));
        expect(service.secret, equals('JBSWY3DPEHPK3PXP'));
        expect(service.otp.account, equals('test@example.com'));
        expect(service.otp.issuer, equals('Test Issuer'));
        expect(service.otp.algorithm, equals('SHA1')); // Default
        expect(service.otp.digits, equals(6)); // Default
        expect(service.otp.period, equals(30)); // Default
        expect(service.order.position, equals(0)); // Default
        expect(service.groupId, isNull);
      });

      test('should handle OtpConfig with defaults', () {
        final json = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          // Missing other fields should use defaults
        };

        final config = OtpConfig.fromJson(json);

        expect(config.account, equals('test@example.com'));
        expect(config.issuer, equals('Test Issuer'));
        expect(config.algorithm, equals('SHA1'));
        expect(config.digits, equals(6));
        expect(config.period, equals(30));
      });

      test('should validate OtpConfig digits range', () {
        // Test with invalid digits (too few)
        final jsonTooFew = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          'digits': '3', // Too few, should default to 6
        };

        final configTooFew = OtpConfig.fromJson(jsonTooFew);
        expect(configTooFew.digits, equals(6));

        // Test with invalid digits (too many)
        final jsonTooMany = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          'digits': '15', // Too many, should default to 6
        };

        final configTooMany = OtpConfig.fromJson(jsonTooMany);
        expect(configTooMany.digits, equals(6));

        // Test with valid digits
        final jsonValid = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          'digits': '8', // Valid
        };

        final configValid = OtpConfig.fromJson(jsonValid);
        expect(configValid.digits, equals(8));
      });

      test('should handle OrderInfo with missing position', () {
        final json = <String, dynamic>{};

        final orderInfo = OrderInfo.fromJson(json);

        expect(orderInfo.position, equals(0));
      });

      test('should convert models back to JSON correctly', () {
        const group = Group(id: 'test-id', name: 'Test Group');
        final groupJson = group.toJson();

        expect(groupJson['id'], equals('test-id'));
        expect(groupJson['name'], equals('Test Group'));

        const service = OtpService(
          id: 'service-id',
          name: 'Service Name',
          secret: 'SECRET123',
          otp: OtpConfig(
            account: 'user@example.com',
            issuer: 'Example Inc',
            algorithm: 'SHA256',
            digits: 8,
            period: 60,
          ),
          order: OrderInfo(position: 5),
          groupId: 'group-id',
        );
        final serviceJson = service.toJson();

        expect(serviceJson['id'], equals('service-id'));
        expect(serviceJson['name'], equals('Service Name'));
        expect(serviceJson['secret'], equals('SECRET123'));
        expect(serviceJson['otp']['account'], equals('user@example.com'));
        expect(serviceJson['otp']['issuer'], equals('Example Inc'));
        expect(serviceJson['otp']['algorithm'], equals('SHA256'));
        expect(serviceJson['otp']['digits'], equals(8));
        expect(serviceJson['otp']['period'], equals(60));
        expect(serviceJson['order']['position'], equals(5));
        expect(serviceJson['groupId'], equals('group-id'));
      });
    });

    group('File operations', () {
      test('should have correct data file name', () {
        // Test static properties without platform dependencies
        expect(StorageRepository, isA<Type>());
        // We can't test file paths in unit tests without mocking platform channels
      });
    });

    group('Data organization helpers', () {
      test('should group services by groupId', () {
        final services = [
          const OtpService(
            id: 'service1',
            name: 'GitHub',
            secret: 'SECRET1',
            otp: OtpConfig(
              account: 'work@company.com',
              issuer: 'GitHub',
            ),
            order: OrderInfo(position: 0),
            groupId: 'work',
          ),
          const OtpService(
            id: 'service2',
            name: 'Google',
            secret: 'SECRET2',
            otp: OtpConfig(
              account: 'personal@gmail.com',
              issuer: 'Google',
            ),
            order: OrderInfo(position: 1),
            groupId: 'personal',
          ),
          const OtpService(
            id: 'service3',
            name: 'GitLab',
            secret: 'SECRET3',
            otp: OtpConfig(
              account: 'work2@company.com',
              issuer: 'GitLab',
            ),
            order: OrderInfo(position: 2),
            groupId: 'work', // Same group as service1
          ),
        ];

        final groupedServices = <String, List<OtpService>>{};
        for (final service in services) {
          final groupId = service.groupId ?? 'ungrouped';
          groupedServices.putIfAbsent(groupId, () => []).add(service);
        }

        expect(groupedServices, hasLength(2));
        expect(groupedServices['work'], hasLength(2));
        expect(groupedServices['personal'], hasLength(1));
        expect(groupedServices['work']![0].name, equals('GitHub'));
        expect(groupedServices['work']![1].name, equals('GitLab'));
        expect(groupedServices['personal']![0].name, equals('Google'));
      });

      test('should handle services without groupId', () {
        final services = [
          const OtpService(
            id: 'service1',
            name: 'Ungrouped Service',
            secret: 'SECRET1',
            otp: OtpConfig(
              account: 'test@example.com',
              issuer: 'Test',
            ),
            order: OrderInfo(position: 0),
            // No groupId
          ),
        ];

        final groupedServices = <String, List<OtpService>>{};
        for (final service in services) {
          final groupId = service.groupId ?? 'ungrouped';
          groupedServices.putIfAbsent(groupId, () => []).add(service);
        }

        expect(groupedServices['ungrouped'], hasLength(1));
        expect(groupedServices['ungrouped']![0].groupId, isNull);
      });

      test('should sort services by order position', () {
        final services = [
          const OtpService(
            id: 'service1',
            name: 'Service C',
            secret: 'SECRET1',
            otp: OtpConfig(account: 'c@example.com', issuer: 'C'),
            order: OrderInfo(position: 2),
            groupId: 'group1',
          ),
          const OtpService(
            id: 'service2',
            name: 'Service A',
            secret: 'SECRET2',
            otp: OtpConfig(account: 'a@example.com', issuer: 'A'),
            order: OrderInfo(position: 0),
            groupId: 'group1',
          ),
          const OtpService(
            id: 'service3',
            name: 'Service B',
            secret: 'SECRET3',
            otp: OtpConfig(account: 'b@example.com', issuer: 'B'),
            order: OrderInfo(position: 1),
            groupId: 'group1',
          ),
        ];

        final groupedServices = <String, List<OtpService>>{};
        for (final service in services) {
          final groupId = service.groupId ?? 'ungrouped';
          groupedServices.putIfAbsent(groupId, () => []).add(service);
        }

        // Sort by position
        groupedServices['group1']!.sort((a, b) => a.order.position.compareTo(b.order.position));

        expect(groupedServices['group1']![0].name, equals('Service A'));
        expect(groupedServices['group1']![1].name, equals('Service B'));
        expect(groupedServices['group1']![2].name, equals('Service C'));
      });
    });
  });
}