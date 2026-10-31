# Seller dashboard and analytics integration

The Flutter seller dashboard supports demo records and a separate authenticated
analytics endpoint. This repository contains no API server or running database.
`lumear_ecommerce.sql` is a **fresh database design**, not an upgrade migration.
The integration partner must implement these routes, import/test the schema on a
disposable database, and migrate existing data before enabling connected mode.

## Date and metric contract

`GET /seller/analytics?start=2026-10-01&end=2026-11-01`

Dates represent Philippine calendar dates (UTC+8). `start` is inclusive and `end`
exclusive. The UI's Today, This week (Monday onward), This month and Custom dates
include the selected end date. Convert request dates to UTC before querying:
October 1 midnight PH is September 30 16:00 UTC. Return zero-filled daily rows in
ascending date order. Reject invalid/reversed ranges. Return the complete selected
range rather than silently truncating it. Apply sensible rate limits to reports.

`previous` covers the immediately preceding range with the same number of calendar
days: `[start - (end - start), start)`. The UI and PDF display both ranges. This is
an adjacent equal-duration comparison; week/month-to-date may compare against a
partial preceding calendar week/month. Percentage changes with a zero prior value
display “No previous baseline”; conversion changes use percentage points.

Both periods use **order placement dates**, with the order's current status:

| Key | Calculation |
| --- | --- |
| `sales` | Sum merchandise subtotals of completed orders; excludes shipping |
| `orders` | All placed orders, including cancelled orders |
| `earnings` | Completed merchandise subtotals minus recorded commission and actual refunded amounts; excludes shipping and payout timing |
| `conversion` | Completed orders / shop visits × 100; zero when visits = 0 |
| `units` | Sum completed OrderItems quantities |
| `aov` | Completed merchandise subtotals / number of completed orders; zero when none |
| `cancelled` | Number of cancelled orders placed within the range |
| `returned` | Distinct completed orders with actual refunded amounts, placed within the range |

This is an operational merchandise report. Discounts and funding allocations remain
separate from this existing earnings basis; do not label it a settled wallet or
cash reconciliation. The Earnings tab retains its separate completion-date income
report and payout balances. Late completion/cancellation/refunds can change an old
placement-date report. Store downloaded reports if a historical snapshot is needed.

All monetary numbers are integer **PHP centavos**, except computed `aov` may be a
fraction rounded for display. Rates are percentages (e.g. `2.5`, not `0.025`). IDs
are JSON strings and boolean fields are JSON booleans. Return every metric key,
even when zero. Empty arrays mean no records; do not omit required sections.

Example response (illustrative values):

```json
{
  "current": {"sales":100000,"orders":4,"earnings":90000,"conversion":2,"units":3,"aov":50000,"cancelled":1,"returned":0},
  "previous": {"sales":80000,"orders":3,"earnings":72000,"conversion":1,"units":2,"aov":40000,"cancelled":0,"returned":0},
  "daily": [{"date":"2026-10-01","revenue":100000}],
  "products": [{"id":"11","name":"Market tote","views":100,"cart_rate":8,"purchases":2,"units":3,"revenue":100000,"low_performing":false,"stock":3}],
  "customers": {"new":1,"returning":1,"repeat":0,"locations":[{"name":"Quezon City","buyers":2}]},
  "promotions": [{"id":"voucher:7","name":"Weekend voucher","kind":"voucher","active":true,"views":50,"claims":10,"redemptions":1,"revenue":50000,"conversion":2,"warning":"Ends in 12 hours"}],
  "operations": {"new":1,"packing":1,"shipped":2,"delivered":8,"delayed":1,"returns":1},
  "returns": [{"id":"9","order_id":"1004","reason":"Damaged item","status":"requested","amount":45000}],
  "notifications": [{"id":"42","type":"new_order","title":"Order 1005 needs packing","read":false}]
}
```

The daily array above is abbreviated; a real response includes all requested dates.
Connected errors show a retry state and never substitute sample records.

## Product and customer aggregation

Sort products by completed units sold descending (stable product ID tie break).
Aggregate completed OrderItems **before joining** to visits/events so a multi-item
order or many event rows cannot multiply revenue. `purchases` is distinct completed
orders containing the product, `units` is quantity, `revenue` is line totals.
`views` counts accepted view events. `cart_rate` is distinct shop visits containing
an add-to-cart for that product / distinct visits viewing it × 100. Count only
add-to-cart visits that also viewed that product within the selected range.
`low_performing` means at least 100 views and no completed purchases in the period.
`stock` is **current** ProductVariants stock, not historical period stock. Flag
stock <= 5; distinguish zero as out of stock. Include products with no sales.

Use buyer **user IDs**, never display names, to count distinct completed buyers.
New buyers have no earlier completed order with this shop before range start;
returning buyers do. Repeat buyers have two or more completed orders within the
selected range. Group optional locations using order address snapshots, counting
each buyer once per location (a buyer may appear in more than one location).
Return an empty `locations` list when unavailable. Suppress small groups under the
partner's privacy policy; never expose street addresses in an aggregate report.

## Promotion sources and attribution

- `ShopVisits`: one visit per server-validated shop/session key. `visitor_hash`
  is a server-generated pseudonymous hash, not an IP address or raw device ID.
- `ProductEvents`: product views/add-to-cart, idempotent per shop/request ID.
- `PromotionEvents`: voucher/flash-sale view impressions, tied to the same shop
  visit. Exactly one target is required. Seller vouchers must have that shop ID;
  platform-wide vouchers are outside this seller promotion ownership contract.
- Voucher claims come from UserVouchers.claimed_at. Redemptions come from
  OrderVouchers joined to completed Orders within the placement-date range.
  Generated revenue is the completed merchandise subtotal of each distinct
  attributed order. Count each order once per voucher. Revenue across promotions
  can overlap when multiple vouchers are allowed; never sum it as shop revenue.
- `FlashSales` and `FlashSaleItems` define dates, active status, sale price and
  allocation limit. `FlashSalePurchases` records attribution for each order item
  at checkout. Count distinct completed attributed orders for redemptions;
  revenue is attributed line totals, units sum attributed item quantities.
  Flash sales do not have voucher claims; return claims = 0.
- Promotion conversion is distinct completed attributed orders / accepted
  promotion views × 100, zero for no views. Historical orders retain their
  attribution after a promotion is paused. Do not create purchase/redemption
  totals from untrusted client telemetry.
- Return warning text for expiry within 24 hours, exhausted voucher usage limits,
  flash-sale allocation remaining <= 5 or underlying variant stock <= 5.
  Display current active/paused state separately from the historical metrics.
  Pausing blocks future eligibility and preserves existing order history.

Record events through the partner's buyer instrumentation, e.g.
`POST /analytics/events` with `request_id`, `visit_key`, `type`, `product_id` or a
promotion identifier. The server resolves shop ownership and timestamps, filters
bots/retries, establishes visits and validates targets. Do not accept financial
fields or caller-selected user IDs. The Flutter buyer currently has no telemetry
producer; connected traffic metrics require that instrumentation in the shared
backend/buyer client. Zero traffic must be returned honestly until tracking exists.
Set retention and deletion policies for these event tables before deployment.

`SellerOrderFacts` pre-aggregates items and actual refunds into one row per order.
`SellerDailySales` groups those facts by shop and Philippine placement date. These
views provide the sales/earnings/order/units/cancellation/refund foundation without
join multiplication. Queries must still filter the session's shop, zero-fill missing
dates, calculate AOV/conversion and assemble customer/product/promotion sections.
Views are internal server helpers, not public client database access.

## Live order snapshot, returns and notifications

`operations`, `returns`, product stock and notifications describe the **current**
shop regardless of selected report dates. Read them in the same consistent
snapshot as the period aggregates where possible. The screen/PDF labels them
accordingly.

`new` = pending/accepted; `packing` = packed/ready_to_ship; `shipped` = in_transit;
`delivered` = delivered/completed. `delayed` counts unfulfilled orders past
pack_due_at or in-transit orders past delivery_due_at. Do not invent deadlines for
orders missing those values. `returns` counts RefundRequests status requested or
approved awaiting resolution; the returns array includes ID, order ID, reason,
status and requested centavos. Authorize through the order's shop.

Notifications uses existing Notifications rows owned by the signed-in seller.
Supported types: `low_stock`, `new_order`, `seller_message` (buyer message received
by seller), `promotion_ending`, `payout_update`, `return_dispute`. Generate/deduplicate
them on backend events and schedule expiry warnings. Keep notification delivery
separate from its read state; use DeviceTokens for background delivery. The demo
uses illustrative message/payout/return notices and a three-day delay threshold.

## Mutations and existing quick actions

| Route | Request / behavior |
| --- | --- |
| `PATCH /seller/promotions/{id}` | `{"active":false}`; IDs use `voucher:7` or `flash_sale:8`; authorize shop and pause transactionally |
| `PATCH /seller/notifications/{id}` | `{"read":true}`; scope to authenticated recipient |
| `POST /seller/orders/{id}/pack` | `{}`; pending/accepted → packed, append history |
| `POST /seller/orders/{id}/ship` | `{}`; packed/ready_to_ship → in_transit after validating the fulfillment provider's handoff requirements; append history |
| `PATCH /seller/products/{id}` | Existing product editor contract, including stock |
| `/chat/threads` and thread messages | Existing authenticated buyer/seller inbox contract |

Every route must require seller role, derive shop from the session and check an
active shop. Lock order/promotion/stock rows for state changes, reject invalid
transitions, make same-state retries safe and append order history once. Shipping
must not change payment status or release earnings. Re-fetch workspace after order
mutations and analytics after every action. The client disables duplicate clicks;
backend authorization, concurrency and retry protection remain mandatory.

PDFs are generated locally from one loaded snapshot using the selected dates,
including comparisons, daily revenue, products, customers, promotions and current
operations/returns. Print/save uses the platform print dialog; export/share uses
the native PDF share/save flow. No report is sent to a buyer automatically.

## Validation before connecting

Test two shops with overlapping event request IDs, cross-shop target rejection,
UTC/Philippine midnight boundaries, empty ranges, zero baselines, multiple items
and promotions per order, repeat buyers under changed display names, cancellation
and refund updates, concurrent stock/flash allocation checkout, paused eligibility,
notification ownership, invalid fulfillment transitions and report totals. Import
and exercise the fresh SQL on MySQL; schema structure alone cannot validate these
transactional rules. No live import has been performed in this workspace.
