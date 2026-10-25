import 'package:flutter/material.dart';

void main() {
  runApp(const AictePortalApp());
}

class AictePortalApp extends StatelessWidget {
  const AictePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AICTE Security Deposit / FDR Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFBF7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          primary: const Color(0xFFF97316),
          surface: Colors.white,
          error: const Color(0xFFDC2626),
        ),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _orange = Color(0xFFF97316);
  static const _deepOrange = Color(0xFFEA580C);
  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _institutionSelected = false;
  bool _passwordVisible = false;
  bool _isLoading = false;
  String? _authenticationError;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    setState(() => _authenticationError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _authenticationError =
          'Sign-in is not connected yet. Please try again later.';
    });
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -75,
            right: -68,
            child: _BackgroundRing(size: 210),
          ),
          const Positioned(
            top: 160,
            left: -100,
            child: _BackgroundRing(size: 165),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 14, 24, 14 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BrandHeader(),
                          const SizedBox(height: 24),
                          Text(
                            _institutionSelected
                                ? 'Welcome'
                                : 'Welcome, Officer',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _institutionSelected
                                ? 'Sign in to manage your institution\'s Fixed Deposit Receipts.'
                                : 'Sign in to review FDRs, resolve discrepancies and manage release approvals.',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 13),
                          if (!_institutionSelected) ...[
                            const _IdentityBadge(),
                            const SizedBox(height: 14),
                          ] else
                            const SizedBox(height: 10),
                          _RoleSelector(
                            institutionSelected: _institutionSelected,
                            onChanged: (selected) => setState(
                              () => _institutionSelected = selected,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FieldLabel(
                                  _institutionSelected
                                      ? 'Institution Email / User ID'
                                      : 'Official Email / Officer ID',
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _userIdController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: _institutionSelected
                                      ? 'Enter your registered email or ID'
                                      : 'Enter your registered officer ID',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  validator: (value) {
                                    final userId = value?.trim() ?? '';
                                    if (userId.isEmpty) {
                                        return _institutionSelected
                                          ? 'Enter your registered email or ID'
                                          : 'Enter your registered officer ID';
                                    }
                                    if (userId.contains('@') &&
                                        !RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                        ).hasMatch(userId)) {
                                      return 'Enter a valid email address or registered ID';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                const _FieldLabel('Password'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_passwordVisible,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
                                  onFieldSubmitted: (_) => _signIn(),
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'Enter your password',
                                    icon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      tooltip: _passwordVisible
                                          ? 'Hide password'
                                          : 'Show password',
                                      onPressed: () => setState(
                                        () => _passwordVisible =
                                            !_passwordVisible,
                                      ),
                                      icon: Icon(
                                        _passwordVisible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: _muted,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Enter your password'
                                      : null,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _showNotice(
                                      'Contact your portal administrator to reset your password.',
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _deepOrange,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 7,
                                      ),
                                      minimumSize: const Size(48, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_authenticationError != null) ...[
                                  const SizedBox(height: 2),
                                  _ErrorMessage(_authenticationError!),
                                  const SizedBox(height: 12),
                                ],
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _signIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _orange,
                                      disabledBackgroundColor: _orange,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shadowColor: _orange.withValues(
                                        alpha: 0.28,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  _institutionSelected
                                                      ? 'Sign In to Institution Portal'
                                                      : 'Sign In to Officer Portal',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 9),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 17),
                          const _OrDivider(),
                          const SizedBox(height: 13),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () => _showNotice(
                                'Institutional SSO is not connected yet.',
                              ),
                              icon: const Icon(
                                Icons.account_balance_outlined,
                                size: 19,
                              ),
                              label: const Text(
                                'Continue with Institutional SSO',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _ink,
                                side: const BorderSide(color: _border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: Color(0xFF16A34A),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Authorized AICTE personnel only',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 17),
                          const Text(
                            'Official Officer Access',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'AICTE Security Deposit / FDR Portal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  const borderColor = Color(0xFFE5E7EB);
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFDC2626)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFE2C7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Color(0xFFEA580C),
            size: 29,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AICTE',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Security Deposit / FDR Portal',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF16A34A)),
            SizedBox(width: 5),
            Text(
              'Secure. Track. Verify. Release.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IdentityBadge extends StatelessWidget {
  const _IdentityBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 14,
              color: Color(0xFFEA580C),
            ),
            SizedBox(width: 6),
            Text(
              'AICTE OFFICER PORTAL',
              style: TextStyle(
                color: Color(0xFFEA580C),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.institutionSelected,
    required this.onChanged,
  });

  final bool institutionSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _RoleOption(
            label: 'Institution',
            selected: institutionSelected,
            onTap: () => onChanged(true),
          ),
          _RoleOption(
            label: 'AICTE Officer',
            selected: !institutionSelected,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF97316) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF97316).withValues(alpha: 0.19),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5563),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF374151),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE5E7EB), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE5E7EB), height: 1)),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundRing extends StatelessWidget {
  const _BackgroundRing({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFE9D5), width: 1.2),
        ),
      ),
    );
  }
}
