const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "13 Oct 2026" from "2026-10-13" (or a full ISO timestamp). Falls back to the input.
String prettyDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_mo[d.month - 1]} ${d.year}';
}

/// "5:16 pm today" / "5:16 pm, 18 Oct" in the device's local time.
String prettyUntil(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return iso ?? '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
  final now = DateTime.now();
  final today = d.year == now.year && d.month == now.month && d.day == now.day;
  return today ? '$t today' : '$t, ${d.day} ${_mo[d.month - 1]}';
}

/// "13 Oct, 5:16 pm" for activity lists, in local time.
String prettyStamp(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return iso ?? '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${_mo[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}
