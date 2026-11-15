/// Working out a sync server address from what she types (docs/sync-server.md). A home server is
/// often plain http on a local address like 10.0.0.20:8797; anything else is usually https.
library;

/// The address with a scheme and no trailing slash. With no scheme, https is assumed.
String cleanServerUrl(String url) {
  var u = url.trim();
  if (!u.contains('://')) u = 'https://$u';
  return u.replaceAll(RegExp(r'/+$'), '');
}

/// Whether she typed a scheme (`http://` or `https://`) herself.
bool hasScheme(String url) => url.trim().contains('://');

bool isPlainHttp(String url) => cleanServerUrl(url).toLowerCase().startsWith('http://');

/// The same address over plain http.
String asPlainHttp(String url) => cleanServerUrl(url).replaceFirst(RegExp(r'^https://', caseSensitive: false), 'http://');

/// An address that only works on a home (local) network: a private IP address, or a name like
/// `nas.local`. Such a server is out of reach whenever she's away from home, and that's expected.
bool isHomeNetworkUrl(String url) {
  final Uri u;
  try {
    u = Uri.parse(cleanServerUrl(url));
  } on FormatException {
    return false;
  }
  return isHomeNetworkHost(u.host);
}

bool isHomeNetworkHost(String host) {
  final h = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
  if (h == 'localhost' || !h.contains('.') && !h.contains(':')) return true; // A bare name, like "nas".
  for (final suffix in const ['.local', '.lan', '.home', '.home.arpa', '.internal', '.localdomain']) {
    if (h.endsWith(suffix)) return true;
  }
  final v4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(h);
  if (v4 != null) {
    final a = int.parse(v4.group(1)!), b = int.parse(v4.group(2)!);
    return a == 10 || a == 127 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) || (a == 169 && b == 254);
  }
  if (h.contains(':')) {
    // IPv6: this computer, unique local (fc00::/7) or link-local (fe80::/10).
    return h == '::1' || RegExp(r'^f[cd][0-9a-f]{0,2}:').hasMatch(h) || RegExp(r'^fe[89ab][0-9a-f]?:').hasMatch(h);
  }
  return false;
}
