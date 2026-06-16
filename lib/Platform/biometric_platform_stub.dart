// Stub for local_auth on web
class LocalAuthentication {
  Future<bool> get canCheckBiometrics async => false;
  Future<bool> isDeviceSupported() async => false;
  Future<bool> authenticate(
      {String? localizedReason, AuthenticationOptions? options}) async {
    return false;
  }
}

class AuthenticationOptions {
  final bool stickyAuth;
  final bool biometricOnly;
  const AuthenticationOptions(
      {this.stickyAuth = true, this.biometricOnly = false});
}
