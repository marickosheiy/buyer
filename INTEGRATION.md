# Shared backend integration

This repository contains the Flutter buyer/seller client. The combined project
will own the backend and database used by buyer, seller, and rider apps.
No live API URL or database credentials are included here.

## Marketplace rules and income reporting

Seller shop editing now opens a full-page route. Profile and background pictures
accept JPG/PNG/WEBP up to 5 MB each and preview before saving. Cancelling discards
unsaved changes. In connected mode, `PATCH /seller/shop` includes only changed
image fields: `profile_image` / `cover_image`, with `{name, type: "image", data}`
(base64 bytes), or explicit `null` to remove an image. The backend must validate,
store and remove these uploads and return them from `GET /seller/workspace` in
`shop.profile_image` / `shop.cover_image` as media objects with stable `url` fields
(plain `profile_image_url` / `cover_image_url` strings are also read). No server
or upload storage is bundled. Demo photos live only for the current session.
Save failures keep the editor and draft open for retry. Checkout confirmation
is now a full-page receipt; Done or Back returns to the cart without reopening
the completed checkout.

- Low stock means **5 units or fewer**, including zero and inactive listings.
  Sellers receive an in-app top notice when entering the seller workspace and
  when a refreshed product falls to or decreases within that range. Repeating
  the same refresh does not repeat the alert. The bell opens the current stock
  notification list. These notifications are session-local; push/background
  notifications need server-side stock events and seller-scoped delivery.
- Shipping is a fixed **PHP 50.00 (5000 centavos) per shop order**, with no
  automatic free-shipping threshold. A multi-shop checkout has one charge per
  shop order. Both connected checkout screens validate each quote's store
  `shipping` field against 5000 and preserve server totals and idempotency.
  The API must enforce this rule when quoting and placing orders; changing
  only Flutter cannot change a deployed backend's prices.
- Platform commission is **10% of merchandise subtotal, excluding shipping**,
  rounded half-up to the nearest centavo per order. The seller gets 90% before
  refunds or separately agreed promotion deductions. Sample records now follow
  this rule. Connected orders preserve recorded `commission` values; reports
  identify historical exceptions rather than rewriting accounting history.
- Income & Earnings filters completed orders by **This Week** (Monday onward),
  **This Month**, **Year to Date** (January 1 through today), **All Time**, or an
  inclusive **Custom date range**, in Philippine time (UTC+8). Custom ranges
  support past years and include the entire end date. The selected dates appear
  on the screen and in PDF/print reports; custom PDF filenames include both dates.
  The screen, saved
  PDF and print job use the same immutable transaction snapshot. Pending,
  delivered-but-uncompleted and cancelled orders are excluded; shipping is
  excluded and recorded `refund` centavos are deducted separately.
- `GET /seller/workspace` must return the complete seller order history for
  these reports (not a truncated recent-orders page), including `completed_at`
  as Unix seconds or an ISO-8601 timestamp with an explicit offset. If completion
  timestamps are missing, reports explicitly disclose use of placement dates.
  Return `refund` as integer centavos (defaults to zero if absent). Wallet and
  payout aggregates remain server-owned and separate from filtered sales.
- PDF export opens the native save dialog; Print opens the platform print
  dialog. The `pdf` and `printing` packages and bundled Apache-licensed Roboto
  fonts generate multipage reports offline with peso glyphs. A native rebuild
  is needed after adding the printing plugin; hot reload alone is insufficient.

Top notifications use a root overlay below the safe top/toolbar area. Their
message body and background allow taps through; only explicit actions intercept
taps. New notices replace old ones, expire automatically, and clear on route
changes or overlay disposal. Existing forms retain their Retry actions.

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

Seller dashboard analytics, promotion controls, notification read state, packing
and shipping actions now have a separate API contract in
[`database/SELLER_ANALYTICS.md`](database/SELLER_ANALYTICS.md). Implement that
contract alongside the existing workspace route. Connected analytics never fall
back to demo data; traffic metrics require shared buyer/backend instrumentation.

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

## Product categories and subcategories

Seller categories appear only as dropdowns in Add/Edit Product, which opens a full-page route with
scrollable fields and persistent Save/Cancel actions. The existing photo/video
upload limits, category dropdowns and one-variety validation are retained.
Each product has one variety,
one price and one stock count. `POST /seller/products` and product PATCH requests
include a single `variant_label` string (defaults to `Default` for an ordinary
listing). The shared backend must create/update exactly one ProductVariants row
per product transactionally; other sizes/colors should be separate products.
The standalone SQL handoff enforces at most one variant with UNIQUE(product_id).
This is not an automatic migration. Existing multi-variant records remain
read-only in the seller client until the backend safely splits them into
separate listings, preserving cart and order references. They are never silently
flattened or deleted. Buyer-side compatibility for existing orders is retained.

`lib/product_categories.dart` is the shared buyer/seller hierarchy: 8 main
categories and 48 subcategories, using the supplied names verbatim. Browse supports
category/subcategory filtering. Seller Add/Edit Product requires a subcategory
belonging to the selected category and clears it when the parent changes.

Product responses and seller create/update requests now include `subcategory`
alongside `category`, both display-name strings. The backend must resolve these
to category/subcategory IDs and validate their parent/child relationship. Older
responses without `subcategory` remain readable; they appear under the main
category and All subcategories until mapped by the integration partner.
The standalone `database/lumear_ecommerce.sql` now includes Subcategories,
Products.subcategory_id, a composite foreign key to enforce the parent category,
and all 56 category/subcategory seed records. `database/README.md` contains the
handoff details and category list. Neither the SQL nor its ZIP is connected to the
app, imported, or run automatically. Seller commission remains 10% as documented.

## Registration address

Contact entry uses the local Philippine mobile format: 11 digits starting with
`09` (`09XXXXXXXXX`). Registration, address editors, and editable seller contact
fields filter non-digits, limit input to 11, and validate before saving. Recognized
existing `+639XXXXXXXXX` contacts are converted to local format when opened in an
editor. The backend must validate incoming phone values too; these client rules
do not change the database or verify that a number is reachable or owned by a user.

Registration now includes an `address` object in `POST /auth/register`: `region`,
`province`, `city`, `barangay`, `street` (house/unit plus street), and `postal_code`
(a four-digit string). Postal code auto-fill uses the bundled PHLPost lookup;
users can confirm or correct it. The shared backend must validate this object and
save it as the new account's address using the account name/phone and its own
address label/default policy. This is a proposed client payload addition; no live
backend or database is connected by the registration UI change.

When backend mode is disabled, registration uses `DemoAccounts` in memory instead
of `/auth/register`; login checks built-in and newly created local accounts.
Demo mode skips email proof and seller document requirements explicitly. Account
emails are normalized and unique, credentials use salted digests in memory, and
nothing is saved to disk. Demo credentials and data must not be used for production
authentication. Backend mode still requires server registration, email proof and
seller uploads; a failed backend request never falls back to creating/logging in
a local account. Accounts clear on process restart; sign-out preserves local
registration records so another local sign-in can be tested. Initial registration
profile/address are restored on sign-in; cart/order/wishlist workspace changes
continue to reset on login as in the existing demo.

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
is closed. Demo chats persist in memory across local account switches, scoped by
buyer and seller identity. Sample product chats are routed to the built-in demo
seller; registered sellers do not receive sample-shop conversations. Connected
chat does not read or write that demo history; live history belongs to the backend.
