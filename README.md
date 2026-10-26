# Lumear buyer and seller app

Flutter buyer and seller interfaces for integration with the rider app's shared
backend. This project does not include a server, database, SQL schemas, database
credentials, or deployment setup.

Run `flutter pub get`, then `flutter run`, or select **Lumear · Buyer and seller
preview** in VS Code. No local server, MySQL, Node, or USB API forwarding is needed.

The app starts in demo mode. Select a buyer or seller demo account on the login
screen, then sign in:

| Role | Email | Password |
| --- | --- | --- |
| Buyer | lumear@gmail.com | Lumear123 |
| Seller | seller@lumear.com | Seller123 |

The Create Account address step auto-fills a postal code from the selected
province and city/municipality using a bundled PHLPost lookup. Missing or ambiguous
codes can be entered manually, and changing location clears the old code. The
same form is used for buyers and sellers. Demo registration works locally; real
registration and email verification require the shared backend.

Demo changes stay in memory and reset when the app restarts. They are not shared
between the buyer, seller, and rider apps. You can create a local buyer or seller
account with **Create an account**, then sign in using its email and password.
Local accounts and their initial profile/address remain in memory until app
restart. No email is sent; demo sellers need shop details but no identity uploads.
Duplicate emails (including the two built-in account emails) are rejected.
Some optional features, such as address lookups,
can still use external internet services.

For future integration, the Flutter API client and connected screens are retained.
See [integration notes](INTEGRATION.md). Existing Render/MySQL services and their
data are unaffected by removing their source and configuration from this project.
Previously uploaded seller documents are preserved in the ignored local
`private_uploads/` folder; they are not app assets or part of the handoff.

In Seller > Products, Add/Edit Product supports up to five photos (JPG, PNG,
WEBP, 5 MB each) and one MP4 video (20 MB). Tap an attachment to preview it;
remove attachments in the editor. Attachments stay in the seller demo session
and are not yet published to buyers. The Dark mode switch turns dark mode on
and returns to light mode when turned off; Android remembers the choice.

Run `flutter analyze` and `flutter test` to check the app. Connected tests use a
mock API and do not need a running server or database.

The login screen also includes **Continue with Google**. Android Google sign-in
is prepared for the shared backend; it requires Google OAuth configuration and
the backend token exchange before real accounts can sign in. Follow
[Google sign-in setup](GOOGLE_SIGN_IN.md).

Chat is available from the floating **Chat** button at the bottom-right, above
the buyer or seller navigation. On a product, tap **Chat with seller** to start a
conversation. Buyer notifications open from the bell in the Home header. To try both sides,
send a message as the buyer, sign out, then open Messages as the demo seller.
Demo chat history stays on this running app and clears on restart. Each buyer
sees their own conversations; the built-in demo seller can reply to conversations
about sample shops. A newly registered seller starts with an empty chat inbox.
It never contacts a real seller.

The chat inbox also includes **Lumear AI assistant**. Demo mode uses clearly labeled
sample replies for app help; it does not run an AI model. Connected mode calls
the proposed shared backend assistant endpoint. Live seller messaging and real
AI replies require the backend work described in [integration notes](INTEGRATION.md).
