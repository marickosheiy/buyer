# Google sign-in setup for Android

The login button and native Google account picker integration are prepared.
No Google Cloud project or backend has been created by this change. Demo mode
explains that Google sign-in is unavailable; it does not authenticate a Google
account or silently create a demo session.

The Lumear project's public Web client ID is configured as the app's default:
`401368596151-qnltc2gebbqu0gui0qtbu5u3j8qf59fu.apps.googleusercontent.com`.
`GOOGLE_SERVER_CLIENT_ID` can override it for another Google Cloud project.
The Android OAuth client and shared backend setup below are still required.

1. Create or select the team's Google Cloud project and configure the Google
   Auth Platform consent screen, audience, and test users while testing.
2. Create an Android OAuth client for package `com.example.flutter_application_1`
   with the SHA-1 fingerprint of the certificate signing the installed APK.
   From `android/`, run `./gradlew.bat signingReport` to inspect fingerprints.
   The current release build also uses the debug signing configuration. Register
   the production/Play signing certificate separately when signing changes.
3. Create a Web application OAuth client in the same project. Its public client
   ID is passed as `GOOGLE_SERVER_CLIENT_ID`; do not pass the Android client ID
   for this value. This implementation supplies it directly to the plugin,
   so Firebase and `google-services.json` are not required for this approach.
4. Have the teammate implement the shared backend contract below.
5. Build/run with all three defines, replacing the placeholders:

```powershell
flutter run --dart-define=ENABLE_BUYER_BACKEND=true --dart-define=API_BASE_URL=https://YOUR-SHARED-HOST/api --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR-WEB-CLIENT-ID.apps.googleusercontent.com
```

Use the same defines with `flutter build apk`. Use an Android device/emulator
with Google Play services. Google configuration changes require rebuilding;
hot reload does not change Dart environment defines. No client secret belongs
in this app. Web/iOS Google sign-in setup is outside the current Android project.

## Proposed shared backend contract

`POST /api/auth/google`, JSON body:

```json
{"id_token": "GOOGLE_ID_TOKEN"}
```

The backend must verify Google's token signature, issuer, expiry, and audience
against the Web OAuth client ID, and identify the account by Google's `sub`.
Return a Lumear session token and the account's server assigned role:

```json
{"token": "LUMEAR_SESSION_TOKEN", "role": "buyer"}
```

`seller` is the other supported role. Google identity alone does not grant a
seller role. The backend should apply the team's account-linking and onboarding
policy; incomplete registration, seller approval, duplicate accounts, or denied
access should return a non-2xx JSON `message`. The current client shows that
message and stays on login. It never assigns a seller role from a Google email.

The Lumear session token is used for the existing buyer/seller workspace calls.
The Google ID token is sent only to the login exchange and is not stored locally.
Logging out ends the Lumear app session; it does not remove the device's Google
account or revoke Google consent.

## Verify after configuration

Test choosing an account, canceling the picker, backend rejection, buyer/seller
routing, logout, and signing in again on the actual Android build. Mock tests
cover token exchange, role validation, cancellation, and demo-mode behavior;
they do not verify Google's native picker or Cloud configuration.

References: [Flutter Google sign-in plugin](https://pub.dev/packages/google_sign_in/versions/7.2.0),
[Android plugin setup](https://pub.dev/packages/google_sign_in_android#integration),
[Google server-side token verification](https://developers.google.com/identity/sign-in/android/backend-auth).
