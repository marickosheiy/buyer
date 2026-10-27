import '../services/marketplace_policy.dart';
import 'seller_commerce.dart';

enum EarningsPeriod {
  week('This Week'),
  month('This Month'),
  yearToDate('Year to Date'),
  custom('Custom Range'),
  allTime('All Time');

  const EarningsPeriod(this.label);
  final String label;
}

/// Calendar filters use Philippine time, independent of the device time zone.
DateTime manilaTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

String incomeDateLabel(DateTime instant) {
  final date = manilaTime(instant);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String incomeMoney(int cents) {
  final amount = (cents.abs() / 100).toStringAsFixed(2).split('.');
  final whole = amount.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${cents < 0 ? '-' : ''}₱$whole.${amount.last}';
}

class IncomeTransaction {
  IncomeTransaction(SellerOrder order)
    : id = order.id,
      date = order.incomeDate,
      gross = order.subtotal,
      commission = order.fee,
      refund = order.refund,
      usesPlacementDate = order.completedAt == null;

  final String id;
  final DateTime date;
  final int gross, commission, refund;
  final bool usesPlacementDate;
  int get net => gross - commission - refund;
}

/// An immutable snapshot shared by the on-screen report, PDF and print job.
class SellerIncomeReport {
  SellerIncomeReport({
    required Iterable<SellerOrder> orders,
    required this.period,
    required this.generatedAt,
    required this.demo,
    this.shopName = 'Lumear Seller',
    this.customStart,
    this.customEnd,
  }) {
    if (period == EarningsPeriod.custom &&
        (customStart == null ||
            customEnd == null ||
            _calendarUtc(customEnd!).isBefore(_calendarUtc(customStart!)))) {
      throw ArgumentError('Choose a start date and an end date in order.');
    }
    final today = manilaTime(generatedAt);
    final month = DateTime.utc(today.year, today.month);
    final monday = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    startAt = switch (period) {
      EarningsPeriod.week => monday.subtract(const Duration(hours: 8)),
      EarningsPeriod.month => month.subtract(const Duration(hours: 8)),
      EarningsPeriod.yearToDate => DateTime.utc(
        today.year,
      ).subtract(const Duration(hours: 8)),
      EarningsPeriod.custom => _calendarUtc(customStart!),
      EarningsPeriod.allTime => null,
    };
    final end = period == EarningsPeriod.custom
        ? _calendarUtc(customEnd!).add(const Duration(days: 1))
        : null;
    rows = List.unmodifiable(
      orders
          .where((o) => o.status == SellerOrderStatus.completed)
          .where((o) => !o.incomeDate.isAfter(generatedAt))
          .where((o) => startAt == null || !o.incomeDate.isBefore(startAt!))
          .where((o) => end == null || o.incomeDate.isBefore(end))
          .map(IncomeTransaction.new)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  final EarningsPeriod period;
  final DateTime generatedAt;
  final bool demo;
  final String shopName;
  final DateTime? customStart, customEnd;
  late final DateTime? startAt;
  late final List<IncomeTransaction> rows;
  int get gross => rows.fold(0, (sum, row) => sum + row.gross);
  int get commission => rows.fold(0, (sum, row) => sum + row.commission);
  int get refunds => rows.fold(0, (sum, row) => sum + row.refund);
  int get net => gross - commission - refunds;
  bool get hasLegacyDates => rows.any((row) => row.usesPlacementDate);
  bool get hasLegacyCommission => rows.any(
    (row) => row.commission != MarketplacePolicy.commissionFor(row.gross),
  );
  String get rangeLabel {
    final end =
        period == EarningsPeriod.custom &&
            _calendarUtc(customEnd!)
                .isBefore(_calendarUtc(manilaTime(generatedAt)))
        ? incomeDateLabel(_calendarUtc(customEnd!))
        : incomeDateLabel(generatedAt);
    return startAt == null
        ? 'All dates through $end'
        : '${incomeDateLabel(startAt!)} – $end';
  }

  String get filename => period == EarningsPeriod.custom
      ? 'lumear-income-custom-${_dateKey(customStart!)}-to-${_dateKey(customEnd!)}.pdf'
      : 'lumear-income-${period.name}-${manilaTime(generatedAt).toIso8601String().substring(0, 10)}.pdf';
}

DateTime _calendarUtc(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).subtract(const Duration(hours: 8));

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
