import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
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

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.subtitle,
    this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final int count;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFFF97316);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.onPressed,
    this.icon,
    this.enabled = true,
    this.fullWidth = true,
    this.maxLines = 2,
  });

  final String label;
  final AppButtonVariant variant;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final bool fullWidth;
  final int maxLines;

  static const double _height = 48;
  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || onPressed == null;
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: isDisabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: isDisabled ? const Color(0xFFE5E7EB) : const Color(0xFFF97316),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(_height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
          child: _AppButtonContent(
            label: label,
            icon: icon,
            isDisabled: isDisabled,
            textColor: Colors.white,
            maxLines: maxLines,
          ),
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDisabled ? const Color(0xFF9CA3AF) : const Color(0xFFF97316),
            side: BorderSide(
              color: isDisabled ? const Color(0xFFE5E7EB) : const Color(0xFFF7C7A3),
            ),
            minimumSize: const Size.fromHeight(_height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
          child: _AppButtonContent(
            label: label,
            icon: icon,
            isDisabled: isDisabled,
            textColor: isDisabled ? const Color(0xFF9CA3AF) : const Color(0xFFF97316),
            maxLines: maxLines,
          ),
        ),
      AppButtonVariant.destructive => OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDisabled ? const Color(0xFF9CA3AF) : const Color(0xFFB91C1C),
            side: BorderSide(
              color: isDisabled ? const Color(0xFFE5E7EB) : const Color(0xFFFCA5A5),
            ),
            minimumSize: const Size.fromHeight(_height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
          child: _AppButtonContent(
            label: label,
            icon: icon,
            isDisabled: isDisabled,
            textColor: isDisabled ? const Color(0xFF9CA3AF) : const Color(0xFFB91C1C),
            maxLines: maxLines,
          ),
        ),
    };

    if (!fullWidth) {
      return SizedBox(height: _height, child: button);
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.label,
    required this.icon,
    required this.isDisabled,
    required this.maxLines,
    required this.textColor,
  });

  final String label;
  final IconData? icon;
  final bool isDisabled;
  final int maxLines;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[];
    if (icon != null) {
      content.add(Icon(icon, size: 18, color: textColor));
      content.add(const SizedBox(width: 8));
    }
    content.add(
      Flexible(
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: content,
    );
  }
}