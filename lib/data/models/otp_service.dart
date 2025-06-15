class OtpService {
  final String id;
  final String name;
  final String? groupId;
  final OtpConfig otp;
  final OrderInfo order;
  final String secret;
  final IconInfo icon;

  const OtpService({
    required this.id,
    required this.name,
    this.groupId,
    required this.otp,
    required this.order,
    required this.secret,
    this.icon = IconInfo.empty,
  });

  factory OtpService.fromJson(Map<String, dynamic> json) {
    return OtpService(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      groupId: json['groupId']?.toString(),
      otp: OtpConfig.fromJson(
          json['otp'] is Map<String, dynamic> ? json['otp'] : {}),
      order: OrderInfo.fromJson(
          json['order'] is Map<String, dynamic> ? json['order'] : {}),
      secret: json['secret']?.toString() ?? '',
      icon: json.containsKey('icon')
          ? IconInfo.fromJson(
              json['icon'] is Map<String, dynamic> ? json['icon'] : {})
          : IconInfo.empty,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'name': name,
      'groupId': groupId,
      'otp': otp.toJson(),
      'order': order.toJson(),
      'secret': secret,
    };

    // Only include icon data if it's not empty
    if (icon != IconInfo.empty) {
      json['icon'] = icon.toJson();
    }

    return json;
  }
}

class OtpConfig {
  final String account;
  final String issuer;
  final int digits;
  final int period;
  final String algorithm;

  const OtpConfig({
    required this.account,
    required this.issuer,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
  });

  factory OtpConfig.fromJson(Map<String, dynamic> json) {
    final digitsValue = json['digits'];
    int digits = 6;
    if (digitsValue != null) {
      try {
        digits = int.parse(digitsValue.toString());
        if (digits < 4 || digits > 10) {
          digits = 6; // Default to 6 if out of valid range
        }
      } catch (e) {
        digits = 6; // Default to 6 if parsing fails
      }
    }

    final periodValue = json['period'];
    int period = 30;
    if (periodValue != null && periodValue is int && periodValue > 0) {
      period = periodValue;
    }

    return OtpConfig(
      account: json['account']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? '',
      digits: digits,
      period: period,
      algorithm: json['algorithm']?.toString() ?? 'SHA1',
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

  const OrderInfo({required this.position});

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    final positionValue = json['position'];
    int position = 0;
    if (positionValue != null && positionValue is int) {
      position = positionValue;
    }
    return OrderInfo(position: position);
  }

  Map<String, dynamic> toJson() => {
        'position': position,
      };
}

class IconInfo {
  final String? iconCollection;
  final String? serviceTypeID;
  final String? labelText;
  final String? labelBackgroundColor;

  const IconInfo({
    this.iconCollection,
    this.serviceTypeID,
    this.labelText,
    this.labelBackgroundColor,
  });

  factory IconInfo.fromJson(Map<String, dynamic> json) {
    return IconInfo(
      iconCollection: json['iconCollection']?.toString(),
      serviceTypeID: json['serviceTypeID']?.toString(),
      labelText: json['labelText']?.toString(),
      labelBackgroundColor: json['labelBackgroundColor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'iconCollection': iconCollection,
        'serviceTypeID': serviceTypeID,
        'labelText': labelText,
        'labelBackgroundColor': labelBackgroundColor,
      };

  IconInfo copyWith({
    String? iconCollection,
    String? serviceTypeID,
    String? labelText,
    String? labelBackgroundColor,
  }) {
    return IconInfo(
      iconCollection: iconCollection ?? this.iconCollection,
      serviceTypeID: serviceTypeID ?? this.serviceTypeID,
      labelText: labelText ?? this.labelText,
      labelBackgroundColor: labelBackgroundColor ?? this.labelBackgroundColor,
    );
  }

  static const IconInfo empty = IconInfo();
}
