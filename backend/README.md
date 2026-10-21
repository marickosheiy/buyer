# Lumear mobile API

## Online deployment

Online migration is being prepared separately from the working USB setup.
`host_api.py` serves the existing MySQL API with Waitress on `0.0.0.0:$PORT`
behind the host's HTTPS endpoint. `Dockerfile` copies only the API source and
schema, excluding credentials, local uploads and development archives.

Hosted database settings are in the ignored `.env.cloud`; the Aiven CA certificate
is in the ignored `aiven-ca.pem`. `configure-hosted-db.ps1` saves the Service URI
privately. Hosted connections verify both the certificate and server hostname.
The deployment environment must include MYSQL_SSL_REQUIRED=true and either
MYSQL_SSL_CA (certificate path on the host) or MYSQL_SSL_CA_PEM (certificate text).
It must also include the existing SMTP and EMAIL_OTP_SECRET values as private
environment variables. These settings never belong in the Android APK.

`move_to_cloud.py` copies the local database to the **empty** configured hosted
database, verifies row counts, and retains the local source. It refuses to overwrite
any existing remote tables. Do not run it while changing local accounts/products.
For a free stateless API host, PRIVATE_UPLOAD_STORAGE=mysql stores private seller
documents in MySQL so they survive server restarts. The migration includes the
existing local documents; no public file-download route is added.

After deployment, verify the public HTTPS `/api/health` address, then rebuild the
app with API_BASE_URL set to that HTTPS address plus `/api`. A successful local
connection or an Aiven database alone does not mean the mobile API is online.
The final check must use the tablet with USB disconnected.

Install hosting dependencies with `pip install -r backend/requirements-hosting.txt`.

The Flutter app uses the standalone MySQL database `lumear_clean_dev`. Its
30-table structure is recorded in `schema.sql`. Normal runs do not import the
teammate's `lumear_schema.sql`, seed sample accounts, or replace marketplace data.
The buyer and seller interfaces read and save through the Python API; MySQL
credentials stay on the computer, outside the Flutter app.

## Run on the connected tablet

Select **Lumear · MySQL (phone with adb reverse)** in VS Code's Run and Debug list. The launch
task starts this workspace's API when needed and forwards the tablet's port 8000
through USB. Keep MySQL running and approve USB debugging on the tablet.

To prepare the connection manually from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/connect-phone.ps1
flutter run --dart-define=ENABLE_BUYER_BACKEND=true --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

The Android emulator launch uses `http://10.0.2.2:8000/api` instead. A standalone
installed APK still needs the computer API and USB forwarding during local use.
Server logs are in `build/api.stdout.log` and `build/api.stderr.log`.

## Private database and email settings

`backend/.env.mysql` is ignored by Git. Use `.env.mysql.example` as the template
on a different computer. Never put MySQL or SMTP passwords into Flutter or a
Dart define. Install the backend dependencies if the virtual environment is missing:

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements-mysql.txt
```

For Gmail OTP delivery, enable 2-Step Verification on the sender Google Account,
create an App Password, and run the helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/configure-email.ps1
```

Enter the sender Gmail address and the generated App Password. The password is
hidden while typing. The helper saves SMTP_HOST, SMTP_PORT, SMTP_USERNAME,
SMTP_FROM and SMTP_PASSWORD locally. EMAIL_OTP_SECRET must also contain a private
random value of at least 32 characters. SMTP changes are read for each challenge.
Google Cloud OAuth credentials are not needed for email OTP. Continue with
Google is deferred and its button is absent from the current login screen.

## Accounts and verification

New buyer and seller registration uses email/password and a six-digit code sent
to the supplied inbox. Step 3 is **Verify**. Codes expire after ten minutes, have
five incorrect attempts, and allow resending after sixty seconds. Only a successful
server verification produces the short-lived, single-use registration proof.
Codes and passwords are never returned in API responses or printed in logs.
A failed email send reports an error instead of pretending a code was delivered.

Existing unverified accounts must verify their email after a correct password.
Suspended accounts and existing multi-factor protections remain enforced. There
is no buyer/seller admin screen. Verified seller registration creates an active
shop that can publish directly. Private document uploads are retained without
claiming that an administrator has reviewed them. Mobile sessions expire after
30 minutes idle and are cleared when the API restarts. Password changes invalidate
the previous password's sessions.

For an empty database on a new installation, import `backend/schema.sql` into the
intended database first. The following command adds only missing mobile support
tables; it does not replace existing data:

```powershell
backend/.venv/Scripts/python.exe backend/server.py --storage mysql --setup-mobile
backend/.venv/Scripts/python.exe backend/server.py --storage mysql --check
```

## Connected functionality and limits

- Buyer catalog, variants, persistent cart, wishlist, addresses, profile, order
  details and order-based notifications read and save through the API. An empty
  database displays empty screens rather than invented products or orders.
- Seller products, stock, shop details, order preparation and guarded cancellation
  enforce ownership and active shop status on the server. Single-variant prices
  and stock are editable; multiple-variant listings remain view-only. New products
  publish directly to the buyer catalog when their visibility is active. Buyers
  refresh their catalog to retrieve changes. Hidden listings and restricted shops
  remain unavailable.
- Earnings show recorded sales, wallet balances, journal amounts and payout
  requests. The standalone wallet uses `balance_minor`; an unrecorded pending
  balance is unavailable. No settlement or transfer is simulated.
- Manual payout requests require an existing payout account. A wallet lock,
  deduction of open requests from requestable funds, and retry-key deduplication
  protect requests. The API does not execute payments or expose account numbers.
- COD checkout requires an explicit `MYSQL_SHIPPING_FEE_MINOR` setting and API
  restart. It is a per-seller flat fee in centavos. Commission uses the seller's
  `commission_bps` and integer half-up rounding. Checkout locks stock and creates
  orders, payment records and inventory movements atomically.
- Chat, review writes, product photo hosting, returns, delivery settlement, payout
  execution still need implementation.
  These are not represented as completed actions in the connected app.

The original buyer layout is retained. Light, Dark and System appearance choices
are available from login and the account screens; the initial choice is Light.

For an existing standalone database previously using approval gates, run
`migrations/enable_direct_publishing.sql` once against that database. It activates
pending shops belonging to verified, non-suspended accounts and their pending
products. It preserves visibility switches and restricted seller/product states.
New registrations and products use direct publishing without this migration.

## Verification

```powershell
backend/.venv/Scripts/python.exe -m unittest discover -s backend -v
flutter analyze --no-pub
flutter test --no-pub
```

MySQL integration tests require `RUN_MYSQL_TESTS=1`. They create and drop only a
random `lumear_mobile_test_*` database using the standalone 30-table structure.
The normal application database is never a test target. Test MySQL credentials
can be provided with MYSQL_HOST, MYSQL_PORT, MYSQL_USER and MYSQL_PASSWORD.
SMTP is mocked in automated tests; an accepted live SMTP login alone does not
prove that a particular inbox received a code.

## Optional local preview

**Lumear · Local sample preview** explicitly disables the connected backend and
shows sample screens. It is separate from normal MySQL use. The legacy SQLite
server (`python backend/server.py`) is for sample development only and does not
provide the production MySQL email-verification flow. Do not use sample accounts
to test real registration.
