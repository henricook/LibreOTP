import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';

void main() {
  group('OtpService', () {
    test('should create an OtpService with all fields', () {
      const service = OtpService(
        id: 'test-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
        groupId: 'group-1',
      );

      expect(service.id, equals('test-id'));
      expect(service.name, equals('Test Service'));
      expect(service.otp.account, equals('test@example.com'));
      expect(service.secret, equals('JBSWY3DPEHPK3PXP'));
      expect(service.otp.issuer, equals('Test Issuer'));
      expect(service.otp.algorithm, equals('SHA1'));
      expect(service.otp.digits, equals(6));
      expect(service.otp.period, equals(30));
      expect(service.order.position, equals(0));
      expect(service.groupId, equals('group-1'));
    });

    test('should create OtpService from JSON', () {
      final json = {
        'id': 'test-id',
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
        'groupId': 'group-1',
      };

      final service = OtpService.fromJson(json);

      expect(service.id, equals('test-id'));
      expect(service.name, equals('Test Service'));
      expect(service.otp.account, equals('test@example.com'));
      expect(service.secret, equals('JBSWY3DPEHPK3PXP'));
      expect(service.otp.issuer, equals('Test Issuer'));
      expect(service.groupId, equals('group-1'));
    });

    test('should convert OtpService to JSON', () {
      const service = OtpService(
        id: 'test-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
        groupId: 'group-1',
      );

      final json = service.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['name'], equals('Test Service'));
      expect(json['otp']['account'], equals('test@example.com'));
      expect(json['secret'], equals('JBSWY3DPEHPK3PXP'));
      expect(json['otp']['issuer'], equals('Test Issuer'));
      expect(json['order']['position'], equals(0));
      expect(json['groupId'], equals('group-1'));
    });

    test('should handle equality correctly', () {
      const service1 = OtpService(
        id: 'test-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
      );

      const service2 = OtpService(
        id: 'test-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
      );

      const service3 = OtpService(
        id: 'different-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
      );

      expect(service1, equals(service2));
      expect(service1, isNot(equals(service3)));
    });

    test('should have consistent hashCode', () {
      const service1 = OtpService(
        id: 'test-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
      );

      const service2 = OtpService(
        id: 'test-id',
        name: 'Test Service',
        secret: 'JBSWY3DPEHPK3PXP',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test Issuer',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
        ),
        order: OrderInfo(position: 0),
      );

      expect(service1.hashCode, equals(service2.hashCode));
    });
  });

  group('OtpConfig', () {
    test('should create an OtpConfig with all fields', () {
      const config = OtpConfig(
        account: 'test@example.com',
        issuer: 'Test Issuer',
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      );

      expect(config.account, equals('test@example.com'));
      expect(config.issuer, equals('Test Issuer'));
      expect(config.algorithm, equals('SHA1'));
      expect(config.digits, equals(6));
      expect(config.period, equals(30));
    });

    test('should create OtpConfig from JSON', () {
      final json = {
        'account': 'test@example.com',
        'issuer': 'Test Issuer',
        'algorithm': 'SHA1',
        'digits': 6,
        'period': 30,
      };

      final config = OtpConfig.fromJson(json);

      expect(config.account, equals('test@example.com'));
      expect(config.issuer, equals('Test Issuer'));
      expect(config.algorithm, equals('SHA1'));
      expect(config.digits, equals(6));
      expect(config.period, equals(30));
    });

    test('should convert OtpConfig to JSON', () {
      const config = OtpConfig(
        account: 'test@example.com',
        issuer: 'Test Issuer',
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      );

      final json = config.toJson();

      expect(
          json,
          equals({
            'account': 'test@example.com',
            'issuer': 'Test Issuer',
            'algorithm': 'SHA1',
            'digits': 6,
            'period': 30,
          }));
    });

    test('should handle equality correctly', () {
      const config1 = OtpConfig(
        account: 'test@example.com',
        issuer: 'Test Issuer',
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      );

      const config2 = OtpConfig(
        account: 'test@example.com',
        issuer: 'Test Issuer',
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      );

      const config3 = OtpConfig(
        account: 'different@example.com',
        issuer: 'Test Issuer',
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });

  group('OrderInfo', () {
    test('should create OrderInfo with position', () {
      const orderInfo = OrderInfo(position: 5);

      expect(orderInfo.position, equals(5));
    });

    test('should create OrderInfo from JSON', () {
      final json = {'position': 10};

      final orderInfo = OrderInfo.fromJson(json);

      expect(orderInfo.position, equals(10));
    });

    test('should convert OrderInfo to JSON', () {
      const orderInfo = OrderInfo(position: 3);

      final json = orderInfo.toJson();

      expect(json, equals({'position': 3}));
    });

    test('should handle missing position in JSON', () {
      final json = <String, dynamic>{};

      final orderInfo = OrderInfo.fromJson(json);

      expect(orderInfo.position, equals(0));
    });
  });
}
