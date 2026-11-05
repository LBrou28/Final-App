import '../../backend/models.dart';

const storageLocations = ['fridge', 'freezer', 'cupboard'];

String locationLabel(String id) => switch (id.toLowerCase()) {
  'fridge' => 'Fridge',
  'freezer' => 'Freezer',
  'cupboard' => 'Cupboard',
  _ => id,
};

DateTime calendarDay(DateTime date) => DateTime(date.year, date.month, date.day);

int daysUntil(DateTime date, DateTime now) {
  // UTC calendar components avoid daylight-saving days of 23 or 25 hours.
  return DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

bool isUseSoon(PantryItem item, DateTime now) =>
    item.expiresOn != null && daysUntil(item.expiresOn!, now) <= 7;

List<PantryItem> sortedPantry(Iterable<PantryItem> items) => items.toList()
  ..sort((a, b) {
    final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (a.expiresOn == null) return b.expiresOn == null ? nameOrder : 1;
    if (b.expiresOn == null) return -1;
    final dateOrder = calendarDay(a.expiresOn!).compareTo(calendarDay(b.expiresOn!));
    return dateOrder == 0 ? nameOrder : dateOrder;
  });

String dateLabel(DateTime date) => '${date.month}/${date.day}/${date.year}';

String reminderLabel(PantryItem item, DateTime now) {
  if (item.expiresOn == null) return 'No date entered';
  final days = daysUntil(item.expiresOn!, now);
  if (days < 0) return 'Entered date passed (${dateLabel(item.expiresOn!)})';
  if (days == 0) return 'Entered date is today';
  return 'Entered date: ${dateLabel(item.expiresOn!)} (in $days days)';
}

String? validatePantryQuantity(String? value) {
  final quantity = num.tryParse(value?.trim() ?? '');
  return quantity == null || !quantity.isFinite || quantity <= 0
      ? 'Enter a number greater than zero.' : null;
}
