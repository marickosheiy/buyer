# Lumear database handoff

Send this folder to the integration partner. `lumear_ecommerce.sql` creates a
new MySQL database named `lumear_ecommerce`, its tables, and reference categories.
It is a standalone design proposal, not an export of a live database or a
migration for an existing database. No Flutter code or connection settings are
changed. No server is installed or started, and no SQL is automatically executed.

## Manual import

Use MySQL 8.0.16 or newer, preferably the team's supported MySQL 8.4 release.
Open the SQL file in MySQL Workbench, review it, then execute it on the intended
new development database server. The account must have database/table creation
permissions. Do not run it against production without a migration review.
The script intentionally fails if `lumear_ecommerce` already exists; it does not
drop, replace, or silently reuse existing tables. MySQL DDL is not one atomic
transaction: a failed import may leave earlier tables created. Inspect a partial
import before retrying; do not blindly rerun the whole script.

No MySQL server is available in the current workspace, so this handoff has been
checked structurally but has not been imported or runtime-tested on MySQL.

## Tables and responsibilities

| Area | Tables |
| --- | --- |
| Accounts and login | Users, UserIdentities, AuthSessions |
| Sellers and addresses | Shops, Addresses |
| Catalog | Categories, Subcategories, Products, ProductVariants, ProductMedia |
| Shopping | CartItems, Wishlist, ShopFollowers |
| Promotions | Vouchers, UserVouchers, OrderVouchers |
| Orders and payments | Orders, OrderItems, Payments, OrderStatusHistory, RefundRequests |
| Reviews and seller earnings | Reviews, SellerPayouts, PayoutOrders |
| Alerts | Notifications, DeviceTokens |
| Buyer/seller chat | ChatThreads, ChatMessages |
| Optional AI history | AssistantConversations, AssistantMessages |

There is one buyer/seller role per account and one shop per seller. The backend
must enforce these roles; a foreign key alone does not prove that an account is
a seller or buyer. Rider profiles, assignments and delivery-specific tables are
outside this buyer/seller proposal; the partner should extend their shared rider
schema and agree on ownership of delivery events.

## Important integration decisions

- Money uses integer **PHP centavos** everywhere: `49900` means `PHP 499.00`.
  This matches the connected Flutter API. Do not send peso decimals as centavos.
- Each product needs at least one variant. Products without choices get a
  `Default` variant with its own SKU, price and stock. Derive product stock from
  active variants and product display price from the selected/default or lowest
  active variant according to the agreed catalog policy. Never maintain a second
  independent stock balance on Products.
- All SQL timestamps are UTC. Set the connection timezone to UTC. Most existing
  workspace responses expect Unix seconds; chat expects ISO 8601 with timezone.
- Split a multi-shop checkout into one order per shop. Reuse one server-validated
  checkout request key as `checkout_group`; the unique buyer/group/shop key
  prevents duplicate shop orders. Do not reuse the key for a different checkout.
- OrderItems preserve product names, option labels and purchase prices. Orders
  preserve delivery address snapshots even if the address book changes later.
  Products, users and shops referenced by financial history should be deactivated,
  rather than deleted. Foreign keys use RESTRICT behavior by default.
- Fulfillment states follow the app: pending, accepted, packed, ready_to_ship,
  in_transit, delivered, completed and cancelled. The backend controls allowed
  transitions and writes OrderStatusHistory in the same transaction. Refund
  status is separate from fulfillment status.
- Payment rows support multiple attempts. Confirm payment status from the trusted
  payment provider or authorized COD collection flow; a client request cannot
  mark an order paid. Do not store card numbers, CVVs, or provider secrets here.
- Complete checkout in a transaction: lock stock rows, validate price/availability
  and address ownership, reserve/decrement stock, apply voucher limits, insert
  orders/items/history, and remove purchased cart items. Roll back all changes on
  failure. Restore stock exactly once on an eligible cancellation.
- SQL checks validate individual row totals, but the backend must verify that
  order subtotal equals the sum of item totals and discount equals applied voucher
  totals. Validate voucher eligibility, expiration, claim ownership, usage limits
  and stacking rules with transactional locks. UserVouchers records claims;
  OrderVouchers records actual usage. Decide how cancelled orders restore usage.
- Enforce buyer/order ownership for refunds and reviews. Only eligible delivered
  or completed purchases can be reviewed. Lock payment/refund records when
  approving a refund so cumulative refunds cannot exceed money collected.
- Seller earnings are calculated from eligible orders, commissions, actual refunds
  and payout allocations. Shipping is tracked separately from merchandise revenue;
  agree with the rider team on who receives it. Lock eligible orders when creating
  payouts to prevent double withdrawal. PayoutOrders reserves an order for one
  payout; on rejection release its allocation transactionally before retrying.
  Check that payout amount equals its allocated net order totals.
- **Seller commission is 10% of the merchandise subtotal before voucher discounts,
  excluding shipping.** Orders.commission_centavos is generated automatically as
  `ROUND(subtotal_centavos * 0.10, 0)`; do not supply it in INSERT/UPDATE statements.
  Rounding is to the nearest centavo, half up. Example: a PHP 1,000.00 merchandise
  subtotal has a PHP 100.00 commission, leaving PHP 900.00 before refunds or any
  seller-funded promotion deductions. Voucher funding must be agreed separately;
  a discount does not change this commission base. The API returns the generated
  value as `commission`. The Flutter demo's sample fee amounts are unchanged;
  this handoff is not connected to the app.
- Store media URLs and file names, not base64 uploads, in ProductMedia. The backend
  validates/stores uploaded files and returns stable URLs. Enforce the app's five
  image/one video limits and file-size/type limits before storing attachments.
- `password_hash` holds a server-generated password hash (for example Argon2id or
  bcrypt), never plaintext or an SQL SHA hash of a password. NULL allows a
  Google-only account; password login must reject such an account until password
  setup is completed. No login-ready demo accounts are seeded.
- Verify Google ID tokens on the server, then map Google's `sub` to
  UserIdentities.provider_subject. Never assign seller privileges from an email
  address alone. AuthSessions stores only the SHA-256 digest of a high-entropy
  random bearer token; validate expiry/revocation on every authenticated request.
  Email verification/reset challenge storage is not included; use the partner's
  auth system or add hashed, expiring, one-time challenge records.
- Device tokens are unique across accounts. Transfer or remove a token securely
  on account switching/logout so the old account's alerts are not sent to the
  new account. Push delivery itself is a backend responsibility.

## Mapping to the current Flutter client

The database column names are internal. The backend must map them to the existing
JSON contract; connecting this SQL directly to Flutter is not sufficient.
See `../INTEGRATION.md` and the Dart workspace parsers for complete response fields.

| Client field | Database source / conversion |
| --- | --- |
| Product `id`, `name`, `description` | Products.product_id, product_name, description |
| Product `seller` | Shops.seller_user_id, **not shop_id** |
| Product `store`, `category` | Shops.shop_name, Categories.category_name |
| Product `subcategory` | Subcategories.subcategory_name, joined through Products.subcategory_id |
| Product `variants` | ProductVariants: id, label, price, stock, active |
| Product `images` / `media` | ProductMedia ordered by sort_order, media_id |
| Product rating and review_count | Aggregate Reviews through OrderItems |
| Cart `id`, `product_id`, `variant_id`, quantity | CartItems joined to ProductVariants and Products |
| Profile `name` | Users.full_name |
| Address `name`, `street`, `city`, `default` | recipient_name, house_street, city_municipality, is_default |
| Order `id`, `raw_status`, `date` | order_id, status, placed_at converted to Unix seconds |
| Order `subtotal`, `shipping`, `discount`, `total`, `commission` | Corresponding centavo columns |
| Order `status` | Buyer-friendly display label derived from raw_status |
| Order `items` / `address` / `timeline` | OrderItems / Orders address snapshots / OrderStatusHistory |
| Seller product price, stock | Derived from variants; the current simple editor supports one variant |
| Seller wallet and earnings | Server-calculated aggregates, not caller-supplied balances |
| Notifications `date`, `read` | created_at as Unix seconds, is_read as JSON boolean |

Serialize IDs as strings where the Dart parser expects strings, and booleans as
JSON true/false rather than MySQL 0/1. Map order/shop display labels explicitly.
The proposed enum payment methods describe storage options, not enabled gateways;
only expose methods actually supported by the integrated backend.

## Chat and AI

For `POST /chat/threads`, the mobile `seller_id` is a **seller user ID**. Look up
that seller's Shops row, verify the supplied product belongs to it, then find or
create the unique buyer/shop thread. Every thread read/write must authorize the
signed-in user as either its buyer or its shop's seller. The database foreign
keys do not enforce participant access by themselves.

Map ChatMessages.message_text to `text`, created_at to an ISO 8601 UTC `date`,
and compute `mine` by comparing sender_user_id with the authenticated user ID.
The sender always comes from the authenticated session, never the request body.
The unique thread/sender/request_id key supports safe retry: on a duplicate,
return the existing result only if its text matches; reject a changed payload.

Optional assistant tables store history only; **they do not provide an AI model**.
The current client sends recent history to `POST /chat/assistant` and has no
conversation ID contract. Using persistent assistant history requires an agreed
API extension and client changes; it is not automatically enabled by this schema.
The backend owns provider credentials, system instructions, access control,
retention and rate limits. Assistant replies cannot authorize payment, order,
refund or stock changes. Do not store API secrets in these tables or Flutter.

## Partner validation before integration

Import on a fresh disposable MySQL database, then test valid checkout and chat
flows and rejection of invalid foreign keys, negative/zero quantities, incorrect
totals, mismatched shop/product/variant rows, duplicate cart entries, duplicate
chat request IDs, duplicate payout allocations, and multiple default addresses.
Also test concurrent checkout, refunds, voucher redemption and payout requests
through the backend. These transactional and authorization rules are not replaced
by CREATE TABLE statements.

MySQL references: [CREATE TABLE](https://dev.mysql.com/doc/refman/8.4/en/create-table.html),
[foreign keys](https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html),
[CHECK constraints](https://dev.mysql.com/doc/refman/8.4/en/create-table-check-constraints.html).

## Updated category hierarchy (October 26, 2026)

The fresh-database script now creates 30 tables and seeds the eight main categories
and 48 subcategories below. Products must reference a valid subcategory within
their selected main category. The existing 10% commission calculation is unchanged.

| Main category | Subcategories |
| --- | --- |
| Pet Supplies | Dog Food & Treats; Cat Litter & Accessories; Aquariums & Fish Supplies; Bird Feeders & Food; Pet Grooming Products; Pet Health & Wellness |
| Electronics and Gadgets | Mobile Phones & Accessories; Laptops, Desktops & Monitors; Audio & Video Equipment; Smart Home Devices; Cameras & Photography; Wearable Technology |
| Women's Apparel | Dresses & Skirts; Tops & Blouses; Activewear & Yoga Pants; Lingerie & Sleepwear; Jackets & Coats; Shoes & Accessories |
| Men's Apparel | Suits & Blazers; Casual Shirts & Pants; Outerwear & Jackets; Activewear & Fitness Gear; Shoes & Accessories; Grooming Products |
| Kids and Baby | Baby Clothes & Accessories; Toys & Games; Educational Materials; Strollers & Gear; Nursery Furniture; Safety and Health |
| Home and Garden | Kitchen Appliances; Furniture & Decor; Gardening Tools; Outdoor Living; Home Improvement Tools; Bedding & Bath |
| Sports and Outdoors | Fitness Equipment; Camping & Hiking Gear; Sports Apparel; Cycling & Bikes; Water Sports; Team Sports Equipment |
| Health and Beauty | Skincare Products; Haircare Solutions; Makeup & Cosmetics; Personal Care Appliances; Men's Grooming; Health Supplements |

The API accepts/returns category and subcategory display names; map them to
Categories.category_id and Subcategories.subcategory_id in the shared backend.
Subcategory names repeat across parents (for example Shoes & Accessories), so
always resolve a subcategory together with its parent category.

This is a replacement proposal for a fresh database, not an automatic migration.
If the older schema was already imported, the partner must migrate existing
categories/products, create and backfill subcategories, and only then enforce
the new NOT NULL/composite foreign-key rules. Do not rerun CREATE DATABASE on
an existing database. No database connection or import has been performed.
