/// ISBN helpers: clean what was typed or scanned, check it, and turn ISBN-10s into ISBN-13s.
library;

/// Digits (and a trailing X for ISBN-10) only.
String cleanIsbn(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

bool _isValid13(String s) {
  if (!RegExp(r'^\d{13}$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(s[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10 == int.parse(s[12]);
}

bool _isValid10(String s) {
  if (!RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final v = s[i] == 'X' ? 10 : int.parse(s[i]);
    sum += v * (10 - i);
  }
  return sum % 11 == 0;
}

/// A valid ISBN-13 for [raw] (ISBN-10s are converted), or null if it isn't a valid ISBN.
String? toIsbn13(String raw) {
  final s = cleanIsbn(raw);
  if (s.length == 13) return _isValid13(s) ? s : null;
  if (s.length == 10 && _isValid10(s)) {
    final core = '978${s.substring(0, 9)}';
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(core[i]) * (i.isEven ? 1 : 3);
    }
    return '$core${(10 - sum % 10) % 10}';
  }
  return null;
}

/// Book barcodes are EAN-13s starting 978 or 979.
bool isBookBarcode(String s) => RegExp(r'^97[89]\d{10}$').hasMatch(s) && _isValid13(s);

/// Lower case, no leading article, letters and digits only: for matching titles and authors.
String normaliseForMatch(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'^(the|a|an)\s+'), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
