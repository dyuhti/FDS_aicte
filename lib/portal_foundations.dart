import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

abstract interface class LocalStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class MemoryLocalStorage implements LocalStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}

class SharedPreferencesLocalStorage implements LocalStorage {
  SharedPreferencesLocalStorage(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesLocalStorage> create() async =>
      SharedPreferencesLocalStorage(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<void> clear() async {
    await _preferences.clear();
  }
}

Future<Map<String, dynamic>?> readJson(
  LocalStorage storage,
  String key,
) async {
  final raw = await storage.read(key);
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  return decoded is Map<String, dynamic> ? decoded : null;
}

abstract interface class AuthService {
  Future<bool> authenticate(String userId, String password);
  Future<void> signOut();
  AuthClaims? get currentClaims;
  Future<AuthClaims?> switchRole(AuthRole role);
}

enum AuthRole { officer, institution, grievanceCell, vigilanceCell }

const Map<String, Set<AuthRole>> permissionMatrix = {
  'verify': {AuthRole.officer},
  'approve': {AuthRole.officer},
  'issueNoc': {AuthRole.officer},
  'grievanceClearance': {AuthRole.officer, AuthRole.grievanceCell},
  'vigilanceClearance': {AuthRole.officer, AuthRole.vigilanceCell},
  'auditTrail': {AuthRole.officer},
  'institutionData': {AuthRole.institution},
  'caseHistory': {
    AuthRole.officer,
    AuthRole.institution,
    AuthRole.grievanceCell,
    AuthRole.vigilanceCell,
  },
};

bool roleCanPerform(String action, AuthRole role) =>
    permissionMatrix[action]?.contains(role) ?? false;

class AuthClaims {
  const AuthClaims({
    required this.subject,
    required this.role,
    required this.institutionId,
    required this.issuedAt,
    required this.expiresAt,
    required this.token,
  });

  final String subject;
  final AuthRole role;
  final String? institutionId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String token;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

class PermissionDeniedException implements Exception {
  PermissionDeniedException(this.message);

  final String message;

  @override
  String toString() => 'PermissionDeniedException: $message';
}

class DemoAuthService implements AuthService {
  DemoAuthService({Clock clock = const SystemClock()}) : _clock = clock;

  static const _secret = 'aicte-portal-role-secret';
  final Clock _clock;
  AuthClaims? _claims;

  @override
  AuthClaims? get currentClaims => _claims;

  @override
  Future<bool> authenticate(String userId, String password) async {
    final valid = userId.trim().isNotEmpty && password.trim().isNotEmpty;
    if (!valid) return false;
    final role = userId.contains('institution')
        ? AuthRole.institution
        : AuthRole.officer;
    _claims = _issue(userId, role);
    return true;
  }

  @override
  Future<AuthClaims?> switchRole(AuthRole role) async {
    final current = _claims;
    if (current == null) return null;
    _claims = _issue(
      current.subject,
      role,
      institutionId: role == AuthRole.institution ? 'INST-DEMO-0042' : null,
    );
    return _claims;
  }

  AuthClaims _issue(String subject, AuthRole role, {String? institutionId}) {
    final issuedAt = _clock.now();
    final expiresAt = issuedAt.add(const Duration(hours: 8));
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': subject,
              'role': role.name,
              'institutionId': institutionId,
              'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
              'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
            }),
          ),
        )
        .replaceAll('=', '');
    final signingInput = '$header.$payload';
    final signature = base64Url
        .encode(Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode(signingInput)).bytes)
        .replaceAll('=', '');
    return AuthClaims(
      subject: subject,
      role: role,
      institutionId: institutionId,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      token: '$signingInput.$signature',
    );
  }

  AuthClaims verifyToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw PermissionDeniedException('Invalid access token.');
    final expected = base64Url
        .encode(Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode('${parts[0]}.${parts[1]}')).bytes)
        .replaceAll('=', '');
    if (expected != parts[2]) throw PermissionDeniedException('Access token signature is invalid.');
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch((payload['exp'] as int) * 1000);
    if (!expiresAt.isAfter(_clock.now())) throw PermissionDeniedException('Access token has expired.');
    return AuthClaims(
      subject: payload['sub'] as String,
      role: AuthRole.values.byName(payload['role'] as String),
      institutionId: payload['institutionId'] as String?,
      issuedAt: DateTime.fromMillisecondsSinceEpoch((payload['iat'] as int) * 1000),
      expiresAt: expiresAt,
      token: token,
    );
  }

  @override
  Future<void> signOut() async {
    _claims = null;
  }
}

final AuthService portalAuthService = DemoAuthService();