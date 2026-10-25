# Shared backend integration

This repository contains the Flutter buyer/seller client. The combined project
will own the backend and database used by buyer, seller, and rider apps.
No live API URL or database credentials are included here.

Google login uses the proposed `POST /auth/google` token exchange. See
[Google sign-in setup](GOOGLE_SIGN_IN.md) for OAuth client registration,
build configuration, server verification, and the response contract.

When the shared backend is ready, run:

```powershell
flutter run --dart-define=ENABLE_BUYER_BACKEND=true --dart-define=API_BASE_URL=https://YOUR-SHARED-HOST/api
```

Use the same defines with `flutter build apk` for an integrated APK. The URL must
point to the HTTP API, never directly to MySQL. The client rejects API calls
until a valid HTTP/HTTPS URL is configured. Explicit connected mode reports
service errors without signing in as a demo user.

The retained client currently expects:

- JSON requests/responses, with a base URL ending in `/api`.
- `POST /auth/login` returning `token` and `role` (`buyer` or `seller`).
- Bearer authorization for authenticated calls; `POST /auth/logout` ends a session.
- Email verification through `/auth/email/send` and `/auth/email/verify`, and
  registration through `/auth/register`.
- `GET /buyer/workspace` returning `profile`, `products`, `cart`, `orders`,
  `addresses`, `wishlist`, `notifications`, `vouchers`, and `capabilities`.
- `GET /seller/workspace` returning seller shop, products, orders, earnings,
  payout and capability data. See `SellerCommerce.load` for the exact fields.
- Additional routes for cart, checkout, orders, addresses, wishlist, notifications,
  seller products, payouts, and profile updates. The retained Dart call sites
  describe their current payloads; they must be mapped to the shared API.

`lib/services/api_service.dart` owns transport and session tokens.
`lib/services/buyer_data.dart` and `lib/seller/seller_commerce.dart` map workspace
responses into the existing interfaces. Connected Flutter tests provide example
response shapes, including monetary values in integer centavos.

Agree on shared account IDs, role handling, product/order IDs, order status
transitions, rider assignment, delivery updates, and payment/payout ownership
before enabling the integration. The current demo does not exchange orders with
the rider app. The retained client is an integration starting point; the teammate's
API is not connected or verified by this change.

Product media uses a proposed `media` array in seller product create/update
requests: each item contains `name`, `type` (`image` or `video`) and either
base64 `data` for a new attachment or `url` for an existing attachment. An empty
array removes all attachments. Seller workspace products should return `media`
with stable URLs. Legacy `images` URL arrays are also read as photos.
The shared backend must implement validation, upload storage, removal handling,
and buyer-visible media responses before enabling this feature across accounts.
The current picker allows five photos up to 5 MB each and one MP4 up to 20 MB.

## Seller chat and AI assistant

The Flutter chat client is implemented; these proposed routes still need to be
implemented in the shared backend. All routes use the existing bearer session.
Connected mode reports errors and never substitutes demo conversations or replies.

| Request | JSON response / behavior |
| --- | --- |
| `GET /chat/threads` | `{"threads":[{"id":"t1","name":"Shop or buyer display name"}]}`; only the signed-in user's conversations. |
| `POST /chat/threads` | Body `{"seller_id":"s1","product_id":"p1"}`; return `{"id":"t1","name":"Shop name"}`. Validate product ownership and return the existing buyer/seller thread when one exists. |
| `GET /chat/threads/:id/messages` | `{"messages":[{"text":"Hello","mine":true,"date":"2026-10-24T06:00:00Z"}]}` in chronological order. Compute `mine` relative to the authenticated user; dates are ISO 8601 with timezone. |
| `POST /chat/threads/:id/messages` | Body `{"text":"Hello","request_id":"unique-client-request"}`; return any successful JSON response after durable storage. Deduplicate request IDs per sender/thread so a retry after a lost response cannot send twice. |
| `POST /chat/assistant` | Body `{"messages":[{"role":"user","content":"How do I track my order?"}]}`; return `{"reply":"Open Orders…"}`. The client includes up to 20 recent user/assistant messages plus the new question. |

Enforce thread membership on every read/write. Derive the sender from the bearer
session, validate recipients and product IDs, and reject blank messages or text
over 2,000 characters. The mobile client refreshes an open conversation every
five seconds while its route is visible; manual Refresh and Retry are available.
The inbox refreshes on entry, on return from a conversation, and manually.
Push notifications, unread counts, attachments and background delivery are not
implemented. The current contract fetches full thread history; add pagination
with the backend before large-scale use.

The backend must call the chosen AI provider using a server-side secret. Never
bundle provider keys in Flutter assets, source, or dart-defines. Validate roles,
limit context size, rate-limit calls, and treat client history as untrusted user
content. Apply the assistant instructions on the server; the client must not
supply system instructions or authorize actions. The assistant currently offers
read-only help and cannot change orders, payments, refunds, or stock. If order
context is added, retrieve only data authorized for the signed-in user. Return
service errors when AI is unavailable. No AI provider or live backend is
configured or verified by this client change.

Assistant history stays in the current inbox session and clears when the workspace
is closed. Demo seller chats persist in memory across switches between the two
fictional demo accounts so both sides can be previewed on one device. Connected
chat does not read or write that demo history; live history belongs to the backend.
