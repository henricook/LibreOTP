import 'package:uuid/uuid.dart';

class OtpService {
  final String id;
  final String name;
  final String? groupId;
  final OtpConfig otp;
  final OrderInfo order;
  final String secret;
  final IconInfo icon;
  final int usageCount;
  final DateTime? lastUsedAt;

  static const _uuid = Uuid();

  const OtpService({
    required this.id,
    required this.name,
    this.groupId,
    required this.otp,
    required this.order,
    required this.secret,
    this.icon = IconInfo.empty,
    this.usageCount = 0,
    this.lastUsedAt,
  });

  factory OtpService.fromJson(Map<String, dynamic> json) {
    DateTime? lastUsedAt;
    if (json.containsKey('lastUsedAt') && json['lastUsedAt'] != null) {
      try {
        lastUsedAt = DateTime.parse(json['lastUsedAt'] as String);
      } catch (e) {
        lastUsedAt = null;
      }
    }

    // Generate UUID if id is missing or empty (2FAS exports don't include ids)
    final String serviceId = json['id']?.toString() ?? '';
    final String actualId = serviceId.isEmpty ? _uuid.v4() : serviceId;

    return OtpService(
      id: actualId,
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
      usageCount: json['usageCount'] as int? ?? 0,
      lastUsedAt: lastUsedAt,
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
      'usageCount': usageCount,
    };

    // Only include icon data if it's not empty
    if (icon != IconInfo.empty) {
      json['icon'] = icon.toJson();
    }

    // Include lastUsedAt if it's not null
    if (lastUsedAt != null) {
      json['lastUsedAt'] = lastUsedAt!.toIso8601String();
    }

    return json;
  }

  OtpService copyWith({
    String? id,
    String? name,
    String? groupId,
    OtpConfig? otp,
    OrderInfo? order,
    String? secret,
    IconInfo? icon,
    int? usageCount,
    DateTime? lastUsedAt,
  }) {
    return OtpService(
      id: id ?? this.id,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      otp: otp ?? this.otp,
      order: order ?? this.order,
      secret: secret ?? this.secret,
      icon: icon ?? this.icon,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
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
