import 'package:otp/otp.dart';
import '../../data/models/otp_service.dart';

class OtpGenerator {
  String generateOtp(OtpService service) {
    Algorithm algorithm;
    switch (service.otp.algorithm.toUpperCase()) {
      case 'SHA256':
        algorithm = Algorithm.SHA256;
        break;
      case 'SHA512':
        algorithm = Algorithm.SHA512;
        break;
      case 'SHA1':
      default:
        algorithm = Algorithm.SHA1;
    }

    // Use UTC time for TOTP generation
    final int currentTimeMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

    return OTP.generateTOTPCodeString(
      service.secret,
      currentTimeMillis,
      length: service.otp.digits,
      algorithm: algorithm,
      interval: service.otp.period,
      isGoogle: true, // Ensures correct handling of base32 secrets
    );
  }

  int getRemainingSeconds(OtpService service) {
    final int currentTimeSeconds =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return service.otp.period - (currentTimeSeconds % service.otp.period);
  }
}
