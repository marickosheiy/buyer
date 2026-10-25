import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';

/// Google proves identity; the shared backend issues the Lumear session and role.
abstract final class GoogleLogin {
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '401368596151-qnltc2gebbqu0gui0qtbu5u3j8qf59fu.apps.googleusercontent.com',
  );
  static Future<void>? _initialization;

  /// A canceled account picker returns null without creating a Lumear session.
  static Future<String?> idToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const ApiException(
        'Google sign-in is currently prepared for Android only.',
      );
    }
    if (serverClientId.isEmpty) {
      throw const ApiException(
        'Google sign-in is not configured yet. Please use another sign-in option.',
      );
    }
    try {
      final google = GoogleSignIn.instance;
      await (_initialization ??= google.initialize(
        serverClientId: serverClientId,
      ));
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Google could not verify your account. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const ApiException(
          'Google sign-in setup needs to be completed. Please use another sign-in option.',
        );
      }
      throw const ApiException(
        'Unable to sign in with Google. Please try again.',
      );
    }
  }
}
