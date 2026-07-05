import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/presentation/widgets/otp_table.dart';

void main() {
  group('OtpTable sorting', () {
    const services = [
      OtpService(
        id: '2',
        name: 'Bravo',
        secret: 'SECRET2',
        otp: OtpConfig(account: 'zeta@example.com', issuer: 'Issuer B'),
        order: OrderInfo(position: 1),
      ),
      OtpService(
        id: '1',
        name: 'Alpha',
        secret: 'SECRET1',
        otp: OtpConfig(account: 'beta@example.com', issuer: 'Issuer A'),
        order: OrderInfo(position: 0),
      ),
      OtpService(
        id: '3',
        name: 'Charlie',
        secret: 'SECRET3',
        otp: OtpConfig(account: 'alpha@example.com', issuer: 'Issuer C'),
        order: OrderInfo(position: 2),
      ),
    ];

    test('sorts by name ascending', () {
      final sorted = sortServicesForTable(services, 1, true);
      expect(sorted.map((service) => service.name).toList(),
          equals(['Alpha', 'Bravo', 'Charlie']));
    });

    test('sorts by account ascending', () {
      final sorted = sortServicesForTable(services, 2, true);
      expect(
          sorted.map((service) => service.otp.account).toList(),
          equals([
            'alpha@example.com',
            'beta@example.com',
            'zeta@example.com',
          ]));
    });

    test('sorts by issuer descending', () {
      final sorted = sortServicesForTable(services, 3, false);
      expect(sorted.map((service) => service.otp.issuer).toList(),
          equals(['Issuer C', 'Issuer B', 'Issuer A']));
    });
  });
}
