class OtpDisplayState {
  final String otpCode;
  final String validity;

  const OtpDisplayState({
    required this.otpCode,
    required this.validity,
  });

  static const empty = OtpDisplayState(otpCode: '', validity: '');
}
