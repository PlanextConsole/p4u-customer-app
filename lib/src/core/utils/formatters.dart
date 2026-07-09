import 'package:intl/intl.dart';

final _money =
    NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
final _date = DateFormat('dd MMM yyyy');

String money(num value) => _money.format(value);

String shortDate(Object? value) {
  if (value == null) return '-';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return _date.format(parsed.toLocal());
}
