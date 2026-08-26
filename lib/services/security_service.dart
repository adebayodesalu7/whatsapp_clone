import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class SecurityService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock WhatsApp',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'WhatsApp Lock',
          ),
        ],
      );
      return didAuthenticate;
    } catch (e) {
      print('Auth Error: $e');
      return false;
    }
  }
}
