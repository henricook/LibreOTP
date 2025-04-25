class OtpService {
  final String id;
  final String name;
  final String? groupId;
  final OtpConfig otp;
  final OrderInfo order;
  final String secret;
  String? otpCode;
  String? validity;

  OtpService({
    required this.id,
    required this.name,
    this.groupId,
    required this.otp,
    required this.order,
    required this.secret,
    this.otpCode,
    this.validity,
  });

  factory OtpService.fromJson(Map<String, dynamic> json) {
    return OtpService(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      groupId: json['groupId'],
      otp: OtpConfig.fromJson(json['otp'] ?? {}),
      order: OrderInfo.fromJson(json['order'] ?? {}),
      secret: json['secret'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'groupId': groupId,
    'otp': otp.toJson(),
    'order': order.toJson(),
    'secret': secret,
  };
}

class OtpConfig {
  final String account;
  final String issuer;
  final int digits;
  final int period;
  final String algorithm;

  OtpConfig({
    required this.account,
    required this.issuer,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
  });

  factory OtpConfig.fromJson(Map<String, dynamic> json) {
    return OtpConfig(
      account: json['account'] ?? '',
      issuer: json['issuer'] ?? '',
      digits: int.parse(json['digits']?.toString() ?? '6'),
      period: json['period'] ?? 30,
      algorithm: json['algorithm'] ?? 'SHA1',
    );
  }

  Map<String, dynamic> toJson() => {
    'account': account,
    'issuer': issuer,
    'digits': digits,
    'period': period,
    'algorithm': algorithm,
  };
}

class OrderInfo {
  final int position;

  OrderInfo({required this.position});

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    return OrderInfo(
      position: json['position'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'position': position,
  };
}