import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';

class SignUpPage extends StatefulWidget {
  /// Called when the user taps "Sign in" to go back to the sign-in screen.
  final VoidCallback onSignIn;

  const SignUpPage({super.key, required this.onSignIn});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _passwordVisible = false;
  bool _confirmVisible = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validate() {
    String? nameErr, emailErr, passErr, confirmErr;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty) {
      nameErr = 'Full name is required.';
    } else if (name.length < 2) {
      nameErr = 'Please enter your full name.';
    }

    if (email.isEmpty) {
      emailErr = 'Email address is required.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailErr = 'Please enter a valid email address.';
    }

    if (password.isEmpty) {
      passErr = 'Password is required.';
    } else if (password.length < 6) {
      passErr = 'Password must be at least 6 characters.';
    }

    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your password.';
    } else if (confirm != password) {
      confirmErr = 'Passwords do not match.';
    }

    setState(() {
      _nameError = nameErr;
      _emailError = emailErr;
      _passwordError = passErr;
      _confirmError = confirmErr;
    });

    return nameErr == null &&
        emailErr == null &&
        passErr == null &&
        confirmErr == null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _signUpWithEmail() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    final auth = context.read<AppAuthProvider>();
    auth.clearError();

    final ok = await auth.signUpWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
    );

    // On success the _AuthGate in main.dart routes to ProfileCompletionGate
    // automatically via the auth state change. Nothing to navigate here.
    if (!ok && mounted) {
      // Error is already set in auth.errorMessage — the widget rebuilds.
    }
  }

  Future<void> _signUpWithGoogle() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AppAuthProvider>();
    auth.clearError();
    await auth.signInWithGoogle();
    // _AuthGate handles routing.
  }

  void _clearFirebaseError() {
    final auth = context.read<AppAuthProvider>();
    if (auth.errorMessage != null) auth.clearError();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 32),

                _buildFieldLabel('Full name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  hint: 'Juan dela Cruz',
                  icon: Icons.person_outline_rounded,
                  error: _nameError,
                  inputAction: TextInputAction.next,
                  onSubmitted: (_) => _emailFocus.requestFocus(),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                    _clearFirebaseError();
                  },
                  disabled: auth.isLoading,
                ),

                const SizedBox(height: 20),
                _buildFieldLabel('Email address'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  error: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  inputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                    _clearFirebaseError();
                  },
                  disabled: auth.isLoading,
                ),

                const SizedBox(height: 20),
                _buildFieldLabel('Password'),
                const SizedBox(height: 8),
                _buildPasswordField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  hint: '••••••••',
                  error: _passwordError,
                  visible: _passwordVisible,
                  onToggleVisible: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  inputAction: TextInputAction.next,
                  onSubmitted: (_) => _confirmFocus.requestFocus(),
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                    _clearFirebaseError();
                  },
                  disabled: auth.isLoading,
                ),

                const SizedBox(height: 20),
                _buildFieldLabel('Confirm password'),
                const SizedBox(height: 8),
                _buildPasswordField(
                  controller: _confirmCtrl,
                  focusNode: _confirmFocus,
                  hint: '••••••••',
                  error: _confirmError,
                  visible: _confirmVisible,
                  onToggleVisible: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                  inputAction: TextInputAction.done,
                  onSubmitted: (_) => _signUpWithEmail(),
                  onChanged: (_) {
                    if (_confirmError != null) {
                      setState(() => _confirmError = null);
                    }
                    _clearFirebaseError();
                  },
                  disabled: auth.isLoading,
                ),

                const SizedBox(height: 28),

                if (auth.errorMessage != null) ...[
                  _buildErrorBanner(auth.errorMessage!),
                  const SizedBox(height: 20),
                ],

                _buildSignUpButton(auth.isLoading),
                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),
                _buildGoogleButton(auth.isLoading),
                const SizedBox(height: 28),
                _buildSignInRow(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kBrand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBrand.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: kBrand, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('SwiftBite',
                  style: kSerif.copyWith(
                      color: kBrand,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Create account',
            style: kSerif.copyWith(
                color: kInk,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.1)),
        const SizedBox(height: 10),
        const Text(
          'Sign up to start ordering your\nfavourite meals.',
          style: TextStyle(color: kMuted, fontSize: 15, height: 1.55),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) => Text(label,
      style: const TextStyle(
          color: kInk, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction inputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    bool disabled = false,
  }) {
    final hasError = error != null;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !disabled,
      keyboardType: keyboardType,
      textInputAction: inputAction,
      autocorrect: false,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(color: kInk, fontSize: 15),
      decoration: _inputDec(
          hint: hint, icon: icon, error: error, hasError: hasError),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    String? error,
    required bool visible,
    required VoidCallback onToggleVisible,
    TextInputAction inputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    bool disabled = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !disabled,
      obscureText: !visible,
      textInputAction: inputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(color: kInk, fontSize: 15),
      decoration: _inputDec(
        hint: hint,
        icon: Icons.lock_outline_rounded,
        error: error,
        hasError: error != null,
        suffix: GestureDetector(
          onTap: onToggleVisible,
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
                visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: kMuted),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec({
    required String hint,
    required IconData icon,
    String? error,
    required bool hasError,
    Widget? suffix,
  }) {
    final borderColor = hasError ? kRed : kBorder;
    final focusBorderColor = hasError ? kRed : kBrand;
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kMuted, fontSize: 15),
      errorText: error,
      errorStyle: const TextStyle(color: kRed, fontSize: 12),
      filled: true,
      fillColor: kSurface2,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, size: 18, color: kMuted),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusBorderColor, width: 1.5)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBorder.withValues(alpha: 0.5))),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        border: Border.all(color: kRed.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: kRed, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: kRed, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _signUpWithEmail,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  colors: [kBrand, kBrandDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          color: isLoading ? kSurface2 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                      color: kBrand.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(kMuted)))
            : const Text('Create account',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2)),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Container(height: 1, color: kBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('or',
            style: TextStyle(
                color: kMuted.withValues(alpha: 0.7), fontSize: 13)),
      ),
      Expanded(child: Container(height: 1, color: kBorder)),
    ]);
  }

  Widget _buildGoogleButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _signUpWithGoogle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isLoading ? kSurface2 : kSurface,
          border: Border.all(
              color: isLoading ? kBorder.withValues(alpha: 0.5) : kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleLogo(size: 20, muted: isLoading),
            const SizedBox(width: 12),
            Text('Continue with Google',
                style: TextStyle(
                    color: isLoading ? kMuted : kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style: TextStyle(color: kMuted, fontSize: 14)),
        GestureDetector(
          onTap: widget.onSignIn,
          child: const Text('Sign in',
              style: TextStyle(
                  color: kBrand, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Google 'G' logo (reused from sign_in_page.dart) ──────────────────────────

class _GoogleLogo extends StatelessWidget {
  final double size;
  final bool muted;
  const _GoogleLogo({required this.size, this.muted = false});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter(muted: muted)));
}

class _GoogleLogoPainter extends CustomPainter {
  final bool muted;
  const _GoogleLogoPainter({required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final alpha = muted ? 0.35 : 1.0;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Color.fromRGBO(255, 255, 255, muted ? 0.04 : 0.06));

    final colors = [
      Color.fromRGBO(66, 133, 244, alpha),
      Color.fromRGBO(52, 168, 83, alpha),
      Color.fromRGBO(251, 188, 4, alpha),
      Color.fromRGBO(234, 67, 53, alpha),
    ];
    final sw = size.width * 0.18;
    final arcR = r * 0.68;
    const pad = 0.08;
    final arcs = [
      [-0.52 + pad, 1.57 - pad * 2, 0],
      [1.05 + pad, 1.57 - pad * 2, 1],
      [2.62 + pad, 1.57 - pad * 2, 2],
      [4.19 + pad, 1.57 - pad * 2, 3],
    ];
    for (final a in arcs) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        a[0] as double,
        a[1] as double,
        false,
        Paint()
          ..color = colors[a[2] as int]
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + arcR, cy),
      Paint()
        ..color = Color.fromRGBO(66, 133, 244, alpha)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => old.muted != muted;
}
