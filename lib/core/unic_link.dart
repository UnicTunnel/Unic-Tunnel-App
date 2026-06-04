/// Builds and parses `unic://` connection links.
///
/// Format: `unic://<base64url(json)>` where the JSON has shape
/// `{ v, name, host, port, user, password }`.
///
/// Mirrors `Unic-Tunnel-Panel/internal/links/unic.go`. App and Panel MUST agree
/// on [unicLinkVersion]. Canonical spec: `Unic-Tunnel-Panel/docs/unic-link-spec.md`.
library;

import 'dart:convert';

const int unicLinkVersion = 1;

class UnicPayload {
  final int v;
  final String name;
  final String host;
  final int port;
  final String user;
  final String password;

  const UnicPayload({
    this.v = unicLinkVersion,
    required this.name,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'v': v,
        'name': name,
        'host': host,
        'port': port,
        'user': user,
        'password': password,
      };

  factory UnicPayload.fromJson(Map<String, dynamic> j) => UnicPayload(
        v: (j['v'] as num).toInt(),
        name: j['name'] as String? ?? '',
        host: j['host'] as String,
        port: (j['port'] as num).toInt(),
        user: j['user'] as String,
        password: j['password'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is UnicPayload &&
      other.v == v &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.user == user &&
      other.password == password;

  @override
  int get hashCode => Object.hash(v, name, host, port, user, password);
}

class UnicLinkException implements Exception {
  final String message;
  UnicLinkException(this.message);
  @override
  String toString() => 'UnicLinkException: $message';
}

/// Encodes [p] as a `unic://` link. If [p.v] is 0, defaults to [unicLinkVersion].
String buildUnicLink(UnicPayload p) {
  final j = jsonEncode((p.v == 0 ? UnicPayload(
    name: p.name, host: p.host, port: p.port, user: p.user, password: p.password,
  ) : p).toJson());
  // Base64URL without padding to match Go's base64.RawURLEncoding.
  final b64 = base64Url.encode(utf8.encode(j)).replaceAll('=', '');
  return 'unic://$b64';
}

/// Decodes a `unic://` link. Throws [UnicLinkException] on any malformed input
/// or unsupported version.
UnicPayload parseUnicLink(String link) {
  if (!link.startsWith('unic://')) {
    throw UnicLinkException('not a unic:// link');
  }
  var raw = link.substring('unic://'.length);
  // Accept padded or unpadded base64url; strip then re-pad to a multiple of 4.
  raw = raw.replaceAll('=', '');
  final padded = raw + '=' * ((4 - raw.length % 4) % 4);

  late List<int> bytes;
  try {
    bytes = base64Url.decode(padded);
  } on FormatException catch (e) {
    throw UnicLinkException('base64: ${e.message}');
  }

  late Map<String, dynamic> obj;
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw UnicLinkException('json: expected object, got ${decoded.runtimeType}');
    }
    obj = decoded;
  } on FormatException catch (e) {
    throw UnicLinkException('json: ${e.message}');
  }

  final v = obj['v'];
  if (v is! num || v.toInt() != unicLinkVersion) {
    throw UnicLinkException(
        'unsupported link version $v (this build understands v=$unicLinkVersion)');
  }
  return UnicPayload.fromJson(obj);
}
