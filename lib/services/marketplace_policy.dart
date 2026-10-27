import 'api_service.dart';

/// Money is stored as integer centavos to avoid floating point rounding errors.
abstract final class MarketplacePolicy {
  static const lowStockThreshold = 5;
  static const shippingCentavos = 5000;
  static const shippingPesos = shippingCentavos / 100;
  static const commissionPercent = 10;

  static int commissionFor(int subtotal) => (subtotal + 5) ~/ 10;

  /// Never replace an authoritative server total with a client-side estimate.
  static void validateShippingQuote(Map<String, dynamic> quote) {
    final stores = quote['stores'] as List? ?? [];
    if (stores.isEmpty ||
        stores.any((store) => store['shipping'] != shippingCentavos)) {
      throw const ApiException(
        'Shipping must be ₱50.00 per shop order. The shop needs to update its shipping rate before checkout.',
      );
    }
  }
}
